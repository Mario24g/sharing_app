import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:blitzshare/model/device.dart';

class DeviceDiscoverer {
  final int port;
  final String ip;
  final String deviceId;
  final NetworkInfo networkInfo;
  final Set<String> knownIps;
  final Map<String, DateTime> deviceLastSeen;
  final StreamController<Device> discoveryController;
  final void Function(String ip)? onDeviceDiscovered;

  late Set<String> _localIps;
  RawDatagramSocket? _listeningSocket;
  Timer? _discoveryTimer;
  bool _shouldContinueDiscovery = true;

  DeviceDiscoverer({
    required this.port,
    required this.ip,
    required this.deviceId,
    required this.networkInfo,
    required this.onDeviceDiscovered,
    required this.discoveryController,
    required this.knownIps,
    required this.deviceLastSeen,
  });

  void initialize() async {
    _localIps = await _getLocalIps();
    _startListeningBroadcast();
    _startDiscoveryLoop();
  }

  void _startListeningBroadcast() async {
    try {
      _listeningSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _listeningSocket!.broadcastEnabled = true;

      _listeningSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final Datagram? datagram = _listeningSocket!.receive();
          if (datagram != null) {
            final String senderIp = datagram.address.address;
            final String message = utf8.decode(datagram.data);

            if (message.startsWith("DISCOVER:")) {
              final String responseMessage = "RESPONSE:$deviceId";
              _listeningSocket!.send(utf8.encode(responseMessage), datagram.address, port);
            } else if (message.startsWith("RESPONSE:")) {
              if (_localIps.contains(senderIp)) return;

              if (!knownIps.contains(senderIp)) {
                _addDiscoveredDevice(senderIp, message.substring(9));
              } else {
                deviceLastSeen[senderIp] = DateTime.now();
              }
            }
          }
        }
      });
    } catch (e) {
      print("Error starting broadcast listener: $e");
    }
  }

  void _addDiscoveredDevice(String senderIp, String identification) {
    try {
      final List<String> components = identification.split("|");
      if (components.isEmpty) return;

      knownIps.add(senderIp);
      deviceLastSeen[senderIp] = DateTime.now();

      discoveryController.add(
        Device(
          ip: senderIp,
          name: components[0],
          devicePlatform:
              components.length > 1
                  ? DevicePlatform.values.firstWhere((v) => v.toString() == "DevicePlatform.${components[1]}", orElse: () => DevicePlatform.unknown)
                  : DevicePlatform.unknown,
        ),
      );

      onDeviceDiscovered?.call(senderIp);
    } catch (e) {
      print("Error adding discovered device: $e");
    }
  }

  void _startDiscoveryLoop() {
    _discoveryTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (!_shouldContinueDiscovery) {
        timer.cancel();
        return;
      }
      await sendDiscoveryBroadcast();
    });
  }

  Future sendDiscoveryBroadcast() async {
    RawDatagramSocket? socket;
    try {
      final String broadcastAddress = await networkInfo.getWifiBroadcast() ?? "255.255.255.255";
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final String message = "DISCOVER:$deviceId";

      //SEND DISCOVERY
      for (int i = 0; i < 3; i++) {
        socket.send(utf8.encode(message), InternetAddress(broadcastAddress), port);
        await Future.delayed(Duration(milliseconds: 100));
      }

      //LISTEN FOR RESPONSE
      final Stopwatch stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 2000) {
        final Datagram? datagram = socket.receive();
        if (datagram != null) {
          final String senderIp = datagram.address.address;
          final String responseMessage = utf8.decode(datagram.data);

          if (responseMessage.startsWith("RESPONSE:") && !_localIps.contains(senderIp)) {
            final String identification = responseMessage.substring(9);
            deviceLastSeen[senderIp] = DateTime.now();

            if (!knownIps.contains(senderIp)) {
              _addDiscoveredDevice(senderIp, identification);
            }
          }
        }
        await Future.delayed(Duration(milliseconds: 50));
      }
    } catch (e) {
      print("Discovery broadcast error: $e");
    } finally {
      socket?.close();
    }
  }

  Future<Set<String>> _getLocalIps() async {
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      return interfaces.expand((interface) => interface.addresses).map((addr) => addr.address).toSet();
    } catch (e) {
      print("Error getting local IPs: $e");
      return <String>{};
    }
  }

  void dispose() {
    _shouldContinueDiscovery = false;
    _discoveryTimer?.cancel();
    _listeningSocket?.close();
  }
}
