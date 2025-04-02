import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/*
Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  final int _port = 8888;
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  RawDatagramSocket? _listeningSocket;

  String? _localIp;
  String? _deviceId;
  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final StreamController<Device> _discoveryController =
      StreamController.broadcast();

  Stream<Device> get discoveredDevices => _discoveryController.stream;
  final Map<String, Socket> _tcpSockets = {};

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await _getDeviceInfo();
    _startListening();
    _startTcpServer();
    _monitorDevices();
  }

  Future<Device> getMyDeviceInfo() async {
    final List<String> info = _deviceId!.split("|");

    return Device(
      ip: _localIp!,
      name: info[0],
      deviceType: DeviceType.values.firstWhere(
        (v) => v.toString() == 'DeviceType.${info[1]}',
      ),
    );
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
            if (!_knownIps.contains(senderIp)) {
              final String identification = message.substring(9);
              final List<String> components = identification.split("|");
              _knownIps.add(senderIp);
              _discoveryController.add(
                Device(
                  ip: senderIp,
                  name: components[0],
                  deviceType: DeviceType.values.firstWhere(
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

  void _monitorDevices() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      DateTime now = DateTime.now();
      _deviceLastSeen.removeWhere((ip, lastSeen) {
        if (now.difference(lastSeen).inSeconds > 15) {
          _removeDevice(ip);
          return true;
        }
        return false;
      });
    });
  }

  void _startTcpConnection(String ip) async {
    try {
      Socket socket = await Socket.connect(ip, _port);
      _tcpSockets[ip] = socket;

      (data) {
        String message = utf8.decode(data);
        if (message == "HEARTBEAT") {
          _deviceLastSeen[ip] = DateTime.now();
        } else if (message.startsWith("DISCONNECT")) {
          String disconnectedIp = message.substring(11);

          // Remove device from list
          _deviceLastSeen.remove(disconnectedIp);
          _tcpSockets.remove(disconnectedIp);
          _discoveryController.addError(disconnectedIp);
        }
      };
      _startHeartbeat(socket);
    } catch (e) {
      print("TCP connection failed: $e");
    }
  }

  void _startTcpServer() async {
    ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      _port,
    );

    server.listen((Socket client) {
      client.listen(
        (data) {
          String message = utf8.decode(data);

          if (message == "HEARTBEAT") {
            _deviceLastSeen[client.remoteAddress.address] = DateTime.now();
          }
        },
        onDone: () {
          _removeDevice(client.remoteAddress.address);
        },
        onError: (error) {
          _removeDevice(client.remoteAddress.address);
        },
      );
    });
  }

  void _startHeartbeat(Socket socket) {
    Timer.periodic(Duration(seconds: 5), (timer) {
      socket.write("HEARTBEAT");
    });
  }

  Future sendDiscoveryUDP() async {
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
          _port,
        );
        await Future.delayed(Duration(milliseconds: 500));
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

            _discoveryController.add(
              Device(
                ip: senderIp,
                name: components[0],
                deviceType: DeviceType.values.firstWhere(
                  (v) => v.toString() == 'DeviceType.${components[1]}',
                  orElse: () => DeviceType.unknown,
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

  void dispose() {
    _sendDisconnectMessage();
    _listeningSocket?.close();
    _discoveryController.close();
  }

  void _removeDevice(String ip) {
    _tcpSockets[ip]?.destroy();
    _tcpSockets.remove(ip);
    _knownIps.remove(ip);
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

  /*void _sendDisconnectMessage() async {
    try {
      final String broadcastAddress =
          await _networkInfo.getWifiBroadcast() ?? '255.255.255.255';
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      final String message = "DISCONNECT:$_localIp";
      for (int i = 0; i < 5; i++) {
        print("Sending DISCONNECT: $_localIp");
        socket.send(
          utf8.encode(message),
          InternetAddress(broadcastAddress),
          _port,
        );
        await Future.delayed(Duration(milliseconds: 500));
      }

      socket.close();
    } catch (e) {
      print("Error sending disconnect message: $e");
    }
  }*/
}

class Device {
  final String ip;
  final String name;
  final DeviceType deviceType;
  final String timestamp = DateTime.now().toString();

  Device({required this.ip, required this.name, required this.deviceType});
}

enum DeviceType { windows, linux, macos, android, ios, unknown }
