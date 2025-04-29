import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sharing_app/model/device.dart';

class TCPConnection {
  final int port;
  final String localIp;
  final Map<String, Socket> tcpSockets;
  final Map<String, DateTime> deviceLastSeen;
  final StreamController<Device> discoveryController;
  final void Function(String senderIp)? onTransferRequest;
  final void Function()? onAccept;

  TCPConnection({
    required this.port,
    required this.localIp,
    required this.tcpSockets,
    required this.deviceLastSeen,
    required this.discoveryController,
    required this.onTransferRequest,
    required this.onAccept,
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
        } else if (message.startsWith("NOTIFICATION:")) {
          String content = message.substring(13);
          List<String> components = content.split(":");
          String senderIp = components[0];

          onTransferRequest!.call(senderIp);
        } else if (message.startsWith("ACCEPT")) {
          print("Target device accepted request");

          //onAccept!.call();
        }
      });
    });
  }

  /* MONITOR AND HEARTBEAT */
  void _startHeartbeat(Socket socket) {
    Timer.periodic(Duration(seconds: 3), (timer) {
      socket.write("HEARTBEAT:$localIp");
    });
  }
}
