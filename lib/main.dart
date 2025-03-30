import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: FutureBuilder<String>(
            future: getDeviceId(),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              // Show a loading indicator while waiting for the data
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              // If we got an error
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              // If we got the data successfully
              return Text(snapshot.data ?? 'No device ID found');
            },
          ),
        ),
      ),
    );
  }

  void startListening() async {
    final List<Map<String, dynamic>> discoveredDevices = [];

    RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      8888,
    );

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? packet = socket.receive();
        if (packet != null) {
          String message = utf8.decode(packet.data);
          String senderIP = packet.address.address;

          print("Received: $message from ${packet.address.address}");

          //Extract device info
          List<String> parts = message.split("|");
          if (parts.length == 2) {
            String deviceID = parts[0];
            String deviceType = parts[1];

            // Check if the device is already discovered
            bool alreadyExists = discoveredDevices.any(
              (device) => device["id"] == deviceID,
            );

            if (!alreadyExists) {
              discoveredDevices.add({
                "id": deviceID,
                "ip": senderIP,
                "type": deviceType,
              });

              print("Device added: $deviceID ($deviceType) at $senderIP");
            }
          }

          String responseMessage = "12345678|desktop";
          Uint8List response = utf8.encode(responseMessage);
          socket.send(response, packet.address, packet.port);
        }
      }
    });
  }

  void sendDiscoveryMessage() async {
    Future<RawDatagramSocket> socket = RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    Uint8List message = utf8.encode(await getDeviceId());

    socket.then((s) {
      s.send(message, InternetAddress("255.255.255.255"), 8888);
    });
  }

  Future<String> getDeviceId() async {
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
    print(deviceId);
    return deviceId;
  }
}
