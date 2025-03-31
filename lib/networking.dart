import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

final List<Map<String, dynamic>> discoveredDevices = [];

void sendBroadcast() async {
  try {
    final NetworkInfo info = NetworkInfo();

    String localIp = await NetworkInfo().getWifiIP() ?? '';
    String deviceId = await getDevice();
    String message = "DISCOVERY-REQUEST FROM $deviceId";

    // 1. Get network info directly
    final String wifiBroadcast =
        await info.getWifiBroadcast() ?? "192.168.1.255";

    // 2. Create socket
    final RawDatagramSocket udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      8888,
    );
    udpSocket.broadcastEnabled = true;

    // 3. Listen for responses
    udpSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        final Datagram? datagram = udpSocket.receive();
        if (datagram != null) {
          String senderIp = datagram.address.address;
          if (senderIp != localIp) {
            print(
              "Received from ${datagram.address.address}: ${utf8.decode(datagram.data)}",
            );

            //String senderIp = datagram.address.address;
            String decodedData = utf8.decode(datagram.data);
            bool alreadyfound = discoveredDevices.any(
              (device) => device["ip"] == senderIp,
            );

            if (!alreadyfound) {
              discoveredDevices.add({"ip": senderIp, "device": decodedData});

              print("Device added: $decodedData ($senderIp)");
            }
          }
        }
      }
    });

    // 4. Send broadcast
    final InternetAddress broadcastAddress = InternetAddress(wifiBroadcast);
    final Uint8List data = utf8.encode(message);
    udpSocket.send(data, broadcastAddress, 8888);
  } catch (e) {
    print("Broadcast failed: $e");
  }
}

Future<String> getDevice() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String deviceId = "UnknownDevice";

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceId = "${androidInfo.model}-${androidInfo.id}";
  } else if (Platform.isWindows) {
    WindowsDeviceInfo windowsDeviceInfo = await deviceInfo.windowsInfo;
    deviceId =
        "${windowsDeviceInfo.computerName}-${windowsDeviceInfo.deviceId}";
  } else if (Platform.isLinux) {
    LinuxDeviceInfo linuxDeviceInfo = await deviceInfo.linuxInfo;
    deviceId = "${linuxDeviceInfo.name}-${linuxDeviceInfo.versionId}";
  }
  return deviceId;
}

class NetworkService {
  final int _port = 8888;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  RawDatagramSocket? _listeningSocket;

  String? _localIp;
  String? _deviceId;

  /*
  final StreamController<Map<String, String>> _discoveryController =
      StreamController.broadcast();*/

  final StreamController<DiscoveredDevice> _discoveryController =
      StreamController.broadcast();

  /*Stream<Map<String, String>> get discoveredDevices =>
      _discoveryController.stream;*/

  Stream<DiscoveredDevice> get discoveredDevices => _discoveryController.stream;

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await _getDeviceId();
    _startListening();
  }

  Future<String> _getDeviceId() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return "${androidInfo.model}|${androidInfo.id}|ANDROID";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await _deviceInfo.iosInfo;
      return "${iosDeviceInfo.modelName}|${iosDeviceInfo.systemVersion}|IOS";
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
      return "${windowsInfo.computerName}|${windowsInfo.productName}|WINDOWS";
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await _deviceInfo.linuxInfo;
      return "${linuxDeviceInfo.prettyName}|${linuxDeviceInfo.id}|LINUX";
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await _deviceInfo.macOsInfo;
      return "${macOsDeviceInfo.modelName}|${macOsDeviceInfo.model}|MACOS";
    }
    return "UnknownDevice";
  }

  void _startListening() async {
    _listeningSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _port,
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
            final responseMessage = "RESPONSE:$_deviceId";
            _listeningSocket!.send(
              utf8.encode(responseMessage),
              datagram.address,
              _port,
            );
          }
          //Si recibe un mensaje RESPONSE, añade el dispositivo que ha anunciado su presencia
          else if (message.startsWith("RESPONSE:")) {
            if (senderIp == _localIp) return;

            /*
            _discoveryController.add({
              'ip': senderIp,
              'message': message.substring(9),
              'timestamp': DateTime.now().toString(),
            });*/

            _discoveryController.add(
              DiscoveredDevice(
                ip: senderIp,
                name: message.substring(9), // Extract device name from message
              ),
            );
          }
        }
      }
    });
  }

  Future sendDiscovery() async {
    try {
      final String broadcastAddress =
          await _networkInfo.getWifiBroadcast() ?? '255.255.255.255';
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final String message = "DISCOVER:$_deviceId";
      socket.send(
        utf8.encode(message),
        InternetAddress(broadcastAddress),
        _port,
      );

      final Stopwatch stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 5000) {
        final datagram = socket.receive();
        if (datagram != null) {
          final senderIp = datagram.address.address;
          final responseMessage = utf8.decode(datagram.data);

          if (responseMessage.startsWith("RESPONSE:")) {
            /*_discoveryController.add({
              'ip': senderIp,
              'message': responseMessage.substring(9),
              'timestamp': DateTime.now().toString(),
            });*/

            _discoveryController.add(
              DiscoveredDevice(ip: senderIp, name: message.substring(9)),
            );
          }
        }
        await Future.delayed(
          Duration(milliseconds: 100),
        ); // Prevent blocking the app
      }

      socket.close();
    } catch (e) {
      print("Discovery error: $e");
    }
  }

  void dispose() {
    _listeningSocket?.close();
    _discoveryController.close();
  }
}

class DiscoveredDevice {
  final String ip;
  final String name;
  //final DeviceType deviceType;
  final String timestamp = DateTime.now().toString();

  DiscoveredDevice({
    required this.ip,
    required this.name,
    //required this.deviceType,
  });
}

enum DeviceType { windows, linux, macos, android, ios }
