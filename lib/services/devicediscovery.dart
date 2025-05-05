import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:sharing_app/model/device.dart';

class DeviceDiscoverer {
  final int port;
  final String ip;
  final String deviceId;
  final NetworkInfo networkInfo;
  final Set<String> knownIps;
  final Map<String, DateTime> deviceLastSeen;
  final StreamController<Device> discoveryController;
  final void Function(String ip)? onDeviceDiscovered;

  RawDatagramSocket? _listeningSocket;

  final bool _shouldContinueDiscovery = true;

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

  void initialize() {
    _startListeningBroadcast();
    _startDiscoveryLoop();
  }

  /* BROADCAST DISCOVERY */
  void _startListeningBroadcast() async {
    _listeningSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );
    _listeningSocket!.broadcastEnabled = true;

    _listeningSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _listeningSocket!.receive();
        if (datagram != null) {
          final senderIp = datagram.address.address;
          final message = utf8.decode(datagram.data);

          //Si recibe un mensaje DISCOVER, responde a su remitente para anunciar su presencia
          if (message.startsWith("DISCOVER:")) {
            final responseMessage = "RESPONSE:$deviceId";
            _listeningSocket!.send(
              utf8.encode(responseMessage),
              datagram.address,
              port,
            );
          }
          //Si recibe un mensaje RESPONSE, añade el dispositivo que ha anunciado su presencia
          else if (message.startsWith("RESPONSE:")) {
            if (senderIp == ip) return;
            if (!knownIps.contains(senderIp)) {
              final String identification = message.substring(9);
              final List<String> components = identification.split("|");
              knownIps.add(senderIp);
              discoveryController.add(
                Device(
                  ip: senderIp,
                  name: components[0],
                  devicePlatform: DevicePlatform.values.firstWhere(
                    (v) => v.toString() == 'DevicePlatform.${components[1]}',
                  ),
                ),
              );

              onDeviceDiscovered?.call(senderIp);
            }
          }
        }
      }
    });
  }

  void _startDiscoveryLoop() async {
    while (_shouldContinueDiscovery) {
      await sendDiscoveryBroadcast();
      await Future.delayed(Duration(seconds: 2));
    }
  }

  Future sendDiscoveryBroadcast() async {
    try {
      final String broadcastAddress =
          await networkInfo.getWifiBroadcast() ?? '255.255.255.255';
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final String message = "DISCOVER:$deviceId";

      for (int i = 0; i < 5; i++) {
        socket.send(
          utf8.encode(message),
          InternetAddress(broadcastAddress),
          port,
        );
      }

      final Stopwatch stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 3000) {
        final Datagram? datagram = socket.receive();
        if (datagram != null) {
          final String senderIp = datagram.address.address;
          final String responseMessage = utf8.decode(datagram.data);

          if (responseMessage.startsWith("RESPONSE:")) {
            final String identification = responseMessage.substring(9);
            final List<String> components = identification.split("|");
            deviceLastSeen[senderIp] = DateTime.now();
            discoveryController.add(
              Device(
                ip: senderIp,
                name: components[0],
                devicePlatform: DevicePlatform.values.firstWhere(
                  (v) => v.toString() == 'DeviceType.${components[1]}',
                  orElse: () => DevicePlatform.unknown,
                ),
              ),
            );
          }
        }
        await Future.delayed(Duration(milliseconds: 100));
      }

      socket.close();
    } catch (e) {
      print("Discovery error: $e");
    }
  }
}
