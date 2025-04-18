import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/*
Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  final int port;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  RawDatagramSocket? _listeningSocket;
  void Function(String senderIp, int senderPort)? onTransferRequest;

  NetworkService({this.port = 8888});

  String? _localIp;
  String? _deviceId;
  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final StreamController<Device> _discoveryController =
      StreamController.broadcast();

  Stream<Device> get discoveredDevices => _discoveryController.stream;
  final bool _shouldContinueDiscovery = true;

  final Map<String, Socket> _tcpSockets = {};

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await _getDeviceInfo();
    _startListeningBroadcast();
    _startDiscoveryLoop();
    _startTcpServer();
    _monitorDevices();
  }

  /* DEVICE INFORMATION */
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
            final responseMessage = "RESPONSE:$_deviceId";
            _listeningSocket!.send(
              utf8.encode(responseMessage),
              datagram.address,
              port,
            );
          }
          //Si recibe un mensaje RESPONSE, añade el dispositivo que ha anunciado su presencia
          else if (message.startsWith("RESPONSE:")) {
            if (senderIp == _localIp) return;
            if (!_knownIps.contains(senderIp)) {
              final String identification = message.substring(9);
              final List<String> components = identification.split("|");
              _knownIps.add(senderIp);
              _discoveryController.add(
                Device(
                  ip: senderIp,
                  name: components[0],
                  devicePlatform: DevicePlatform.values.firstWhere(
                    (v) => v.toString() == 'DeviceType.${components[1]}',
                  ),
                ),
              );

              _startTcpConnection(senderIp);
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
          await _networkInfo.getWifiBroadcast() ?? '255.255.255.255';
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final String message = "DISCOVER:$_deviceId";

      for (int i = 0; i < 5; i++) {
        socket.send(
          utf8.encode(message),
          InternetAddress(broadcastAddress),
          port,
        );
        //await Future.delayed(Duration(milliseconds: 500));
      }

      final Stopwatch stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 3000) {
        final datagram = socket.receive();
        if (datagram != null) {
          final senderIp = datagram.address.address;
          final responseMessage = utf8.decode(datagram.data);

          if (responseMessage.startsWith("RESPONSE:")) {
            final String identification = responseMessage.substring(9);
            final List<String> components = identification.split("|");
            _deviceLastSeen[senderIp] = DateTime.now();
            _discoveryController.add(
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

  void _sendDisconnectMessage() async {
    try {
      for (MapEntry<String, Socket> entry in _tcpSockets.entries) {
        Socket socket = entry.value;
        socket.write("DISCONNECT:$_localIp");
        await socket.flush();
        socket.destroy();
      }
      _tcpSockets.clear();
    } catch (e) {
      print("Error sending disconnect message: $e");
    }
  }

  void _sendDisconnectUDP() async {
    final String broadcastAddress =
        await _networkInfo.getWifiBroadcast() ?? '255.255.255.255';
    final RawDatagramSocket socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    socket.broadcastEnabled = true;

    final String message = "DISCONNECT";

    for (int i = 0; i < 5; i++) {
      socket.send(
        utf8.encode(message),
        InternetAddress(broadcastAddress),
        port,
      );
    }
  }
}

class Device {
  final String ip;
  final String name;
  final DevicePlatform devicePlatform;
  final String timestamp = DateTime.now().toString();

  Device({required this.ip, required this.name, required this.devicePlatform});
}

enum DevicePlatform { windows, linux, macos, android, ios, unknown }
