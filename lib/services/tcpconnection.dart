import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sharing_app/model/device.dart';

class TCPConnection {
  final int port;
  final String localIp;
  final Map<String, Socket> tcpSockets;
  final Map<String, DateTime> deviceLastSeen;
  final StreamController<Device> discoveryController;
  final void Function(String senderIp, int senderPort)? onTransferRequest;

  TCPConnection({
    required this.port,
    required this.localIp,
    required this.tcpSockets,
    required this.deviceLastSeen,
    required this.discoveryController,
    required this.onTransferRequest,
  });

  void handleDiscoveredDevice(String ip) {
    _startTcpConnection(ip);
  }

  void initialize() {
    _startTcpServer();
  }

  void _startTcpConnection(String ip) async {
    try {
      Socket socket = await Socket.connect(ip, port);
      tcpSockets[ip] = socket;

      socket.listen((data) {
        String message = utf8.decode(data);
        if (message.startsWith("DISCONNECT")) {
          String disconnectedIp = message.substring(11);

          // Remove device from list
          deviceLastSeen.remove(disconnectedIp);
          tcpSockets.remove(disconnectedIp);
          discoveryController.addError(disconnectedIp);
        } else if (message.startsWith("SEND")) {
          String content = message.substring(5);
          List<String> components = content.split(":");

          String ip = components[0];
          int port = int.parse(components[1]);
          _startTransferClient(ip, port);
        }
      });
      _startHeartbeat(socket);
    } catch (e) {
      print("TCP connection failed: $e");
    }
  }

  void _startTcpServer() async {
    ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );

    server.listen((Socket client) {
      client.listen((data) async {
        String message = utf8.decode(data);
        print("Message received: $message");
        if (message.startsWith("HEARTBEAT:")) {
          String ip = message.substring(10);
          deviceLastSeen[ip] = DateTime.now();
        } else if (message.startsWith("SEND:")) {
          String content = message.substring(5);
          List<String> components = content.split(":");

          String senderIp = components[0];
          int senderPort = int.parse(components[1]);

          _startTransferClient(senderIp, senderPort);
        } else if (message.startsWith("NOTIFICATION:")) {
          String content = message.substring(13);
          List<String> components = content.split(":");

          String senderIp = components[0];
          int senderPort = int.parse(components[1]);

          onTransferRequest!(senderIp, senderPort);
        } else if (message.startsWith("ACCEPT")) {
          print("Target device accepted request");
        }
      });
    });
  }

  void _startTransferClient(String senderIp, int senderPort) async {
    final Socket socket = await Socket.connect(senderIp, senderPort);

    socket.listen((data) async {
      String message = utf8.decode(data).trim();

      List<String> split = message.split(":");
      String fileName = split[0];
      int fileLength = int.parse(split[1]);

      IOSink iosink = File(fileName).openWrite();
      try {
        await socket.listen((data) {
          iosink.add(data);
        }).asFuture();
      } finally {
        iosink.close();
        print("File received: $fileName");
        socket.close();
      }
    });
  }

  List<int> toIntList(Uint8List source) {
    return List.from(source);
  }

  /* MONITOR AND HEARTBEAT */
  void _startHeartbeat(Socket socket) {
    Timer.periodic(Duration(seconds: 3), (timer) {
      socket.write("HEARTBEAT:$localIp");
    });
  }
}
