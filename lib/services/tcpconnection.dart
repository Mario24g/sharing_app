import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blitzshare/model/device.dart';

class TCPConnection {
  final int port;
  final String localIp;
  final Map<String, Socket> tcpSockets;
  final Map<String, DateTime> deviceLastSeen;
  final StreamController<Device> discoveryController;
  final void Function(String senderIp)? onTransferRequest;
  final void Function()? onAccept;
  final void Function(String ip)? onConnectionLost;

  ServerSocket? _server;
  final Map<String, Timer> _heartbeatTimers = {};

  TCPConnection({
    required this.port,
    required this.localIp,
    required this.tcpSockets,
    required this.deviceLastSeen,
    required this.discoveryController,
    required this.onTransferRequest,
    required this.onAccept,
    this.onConnectionLost,
  });

  void handleDiscoveredDevice(String ip) {
    if (!tcpSockets.containsKey(ip)) {
      _startTcpConnection(ip);
    }
  }

  void initialize() async {
    await _startTcpServer();
  }

  void _startTcpConnection(String ip) async {
    try {
      Socket socket = await Socket.connect(ip, port, timeout: Duration(seconds: 5));
      tcpSockets[ip] = socket;

      socket.listen(
        (data) {
          _handleSocketData(data, ip);
        },
        onError: (error) {
          _cleanupConnection(ip);
        },
        onDone: () {
          _cleanupConnection(ip);
        },
      );

      _startHeartbeat(socket, ip);
    } catch (e) {
      _cleanupConnection(ip);
    }
  }

  void _handleSocketData(Uint8List data, String ip) {
    try {
      String message = utf8.decode(data);

      if (message.startsWith("HEARTBEAT:")) {
        String senderIp = message.substring(10);
        deviceLastSeen[senderIp] = DateTime.now();
      } else if (message.startsWith("NOTIFICATION:")) {
        String content = message.substring(13);
        List<String> components = content.split(":");
        if (components.isNotEmpty) {
          String senderIp = components[0];
          onTransferRequest?.call(senderIp);
        }
      } else if (message.startsWith("ACCEPT")) {
        onAccept?.call();
      }
    } catch (e) {
      print("Error handling socket data from $ip: $e");
    }
  }

  Future _startTcpServer() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen((Socket client) {
        String clientIp = client.remoteAddress.address;

        client.listen(
          (data) {
            _handleSocketData(data, clientIp);
          },
          onError: (error) {
            client.destroy();
          },
          onDone: () {
            client.destroy();
          },
        );
      });
    } catch (e) {
      print("Failed to start TCP server: $e");
    }
  }

  void _startHeartbeat(Socket socket, String ip) {
    _heartbeatTimers[ip]?.cancel();

    _heartbeatTimers[ip] = Timer.periodic(Duration(seconds: 3), (timer) {
      try {
        if (!tcpSockets.containsKey(ip) || tcpSockets[ip] != socket) {
          timer.cancel();
          _heartbeatTimers.remove(ip);
          return;
        }

        socket.write("HEARTBEAT:$localIp");
        socket.flush();
      } catch (e) {
        timer.cancel();
        _heartbeatTimers.remove(ip);
        _cleanupConnection(ip);
      }
    });
  }

  void _cleanupConnection(String ip) {
    _heartbeatTimers[ip]?.cancel();
    _heartbeatTimers.remove(ip);
    tcpSockets[ip]?.destroy();
    tcpSockets.remove(ip);

    onConnectionLost?.call(ip);
  }

  void dispose() {
    for (Timer timer in _heartbeatTimers.values) {
      timer.cancel();
    }
    _heartbeatTimers.clear();

    for (Socket socket in tcpSockets.values) {
      socket.destroy();
    }
    tcpSockets.clear();
    _server?.close();
  }
}
