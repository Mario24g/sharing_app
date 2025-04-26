import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:sharing_app/services/devicediscovery.dart';
import 'package:sharing_app/services/filereceiver.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/services/tcpconnection.dart';

/*
TODO: Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  String? _localIp;
  String? _deviceId;
  final int port;
  final NetworkInfo _networkInfo = NetworkInfo();
  final FileReceiver _fileReceiver = FileReceiver(port: 8889);
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  void Function(String senderIp, int senderPort)? onTransferRequest;
  void Function(String ip)? startTcpConnection;

  NetworkService({this.port = 8888});

  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final StreamController<Device> _discoveryController =
      StreamController.broadcast();

  Stream<Device> get discoveredDevices => _discoveryController.stream;

  final Map<String, Socket> _tcpSockets = {};

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await _getDeviceInfo();

    final TCPConnection tcpConnection = TCPConnection(
      port: 8890,
      localIp: _localIp!,
      deviceLastSeen: _deviceLastSeen,
      discoveryController: _discoveryController,
      onTransferRequest: onTransferRequest,
      tcpSockets: _tcpSockets,
    )..initialize();

    DeviceDiscoverer(
      port: 8888,
      ip: _localIp!,
      deviceId: _deviceId!,
      networkInfo: _networkInfo,
      onDeviceDiscovered: tcpConnection.handleDiscoveredDevice,
      discoveryController: _discoveryController,
      knownIps: _knownIps,
      deviceLastSeen: _deviceLastSeen,
    ).initialize();

    _startTcpServer();
    _fileReceiver.startReceiverServer();
    _monitorDevices();
  }

  /* DEVICE INFORMATION */
  Future<String> getMyDeviceInfo() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return "${androidInfo.model} $_localIp";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await _deviceInfo.iosInfo;
      return "${iosDeviceInfo.modelName} $_localIp";
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
      return "${windowsInfo.computerName} $_localIp";
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await _deviceInfo.linuxInfo;
      return "${linuxDeviceInfo.prettyName} $_localIp";
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await _deviceInfo.macOsInfo;
      return "${macOsDeviceInfo.modelName} $_localIp";
    }
    return "Unknown device|unknown";
  }

  Future<String> _getDeviceInfo() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return "${androidInfo.model}|android";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await _deviceInfo.iosInfo;
      return "${iosDeviceInfo.modelName}|ios";
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
      return "${windowsInfo.computerName}|windows";
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await _deviceInfo.linuxInfo;
      return "${linuxDeviceInfo.prettyName}|linux";
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await _deviceInfo.macOsInfo;
      return "${macOsDeviceInfo.modelName}|macos";
    }
    return "Unknown device|unknown";
  }

  /* TCP CONNECTION */
  void _startTcpConnection(String ip) async {
    try {
      Socket socket = await Socket.connect(ip, 8890);
      _tcpSockets[ip] = socket;

      socket.listen((data) {
        String message = utf8.decode(data);
        if (message.startsWith("DISCONNECT")) {
          String disconnectedIp = message.substring(11);

          // Remove device from list
          _deviceLastSeen.remove(disconnectedIp);
          _tcpSockets.remove(disconnectedIp);
          _discoveryController.addError(disconnectedIp);
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
      8890,
      shared: true,
    );

    server.listen((Socket client) {
      client.listen((data) async {
        String message = utf8.decode(data);
        print("Message received: $message");
        if (message.startsWith("HEARTBEAT:")) {
          String ip = message.substring(10);
          _deviceLastSeen[ip] = DateTime.now();
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
      socket.write("HEARTBEAT:$_localIp");
    });
  }

  void _monitorDevices() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      DateTime now = DateTime.now();

      final toRemove =
          _deviceLastSeen.entries
              .where((e) => now.difference(e.value).inSeconds > 6)
              .map((e) => e.key)
              .toList();

      for (final ip in toRemove) {
        _removeDevice(ip);
        _deviceLastSeen.remove(ip);
      }
    });
  }

  /* CLEANUP */
  /*void dispose() {
    //_sendDisconnectMessage();
    _sendDisconnectUDP();
    _listeningSocket?.close();
    _discoveryController.close();
  }*/

  void _removeDevice(String ip) {
    print("Removing device: $ip");
    _tcpSockets[ip]?.destroy();
    _tcpSockets.remove(ip);
    _knownIps.remove(ip);
    _deviceLastSeen.remove(ip);
    _discoveryController.addError(ip);
  }
}
