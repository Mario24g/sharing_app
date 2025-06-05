import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:blitzshare/data/deviceinfo.dart';
import 'package:blitzshare/services/devicediscovery.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/services/tcpconnection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  void Function(String senderIp)? onTransferRequest;
  void Function(String ip)? startTcpConnection;
  void Function(String deviceName)? onDeviceDisconnected;

  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final Map<String, Socket> _tcpSockets = {};
  final Set<Device> _cachedDevices = {};

  late StreamController<Device> _discoveryController = StreamController.broadcast();

  String? _localIp;
  String? _deviceId;
  Timer? _monitorTimer;
  TCPConnection? _tcpConnection;
  DeviceDiscoverer? _deviceDiscoverer;
  bool _isInitialized = false;

  Stream<Device> get discoveredDevices => _discoveryController.stream;

  Future initialize() async {
    if (_isInitialized) return;

    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    final int tcpPort = sharedPreferences.getInt("tcpPort") ?? 7350;
    final int udpPort = sharedPreferences.getInt("udpPort") ?? 7351;

    try {
      _discoveryController = StreamController.broadcast();

      _localIp = await _networkInfo.getWifiIP();
      _deviceId = await DeviceInfo.getDeviceInfo();

      _discoveryController.stream.listen((device) {
        _cachedDevices.add(device);
      });

      _tcpConnection = TCPConnection(
        port: tcpPort,
        localIp: _localIp!,
        deviceLastSeen: _deviceLastSeen,
        discoveryController: _discoveryController,
        tcpSockets: _tcpSockets,
        onConnectionLost: (ip) => _handleConnectionLost(ip),
      );
      _tcpConnection!.initialize();

      _deviceDiscoverer = DeviceDiscoverer(
        port: udpPort,
        ip: _localIp!,
        deviceId: _deviceId!,
        networkInfo: _networkInfo,
        onDeviceDiscovered: _tcpConnection!.handleDiscoveredDevice,
        discoveryController: _discoveryController,
        knownIps: _knownIps,
        deviceLastSeen: _deviceLastSeen,
      );
      _deviceDiscoverer!.initialize();

      _monitorDevices();
      _isInitialized = true;
    } catch (e) {
      dispose();
      rethrow;
    }
  }

  void _handleConnectionLost(String ip) {
    if (_knownIps.contains(ip)) {
      _removeDevice(ip);
    }
  }

  void _monitorDevices() {
    _monitorTimer?.cancel();

    _monitorTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      DateTime now = DateTime.now();
      final List<String> devicesToRemove = _deviceLastSeen.entries.where((e) => now.difference(e.value).inSeconds > 8).map((e) => e.key).toList();

      for (String ip in devicesToRemove) {
        if (_knownIps.contains(ip)) {
          _removeDevice(ip);
        }
      }
    });
  }

  void _removeDevice(String ip) {
    try {
      if (!_knownIps.contains(ip)) return;

      _tcpSockets[ip]?.destroy();
      _tcpSockets.remove(ip);
      _knownIps.remove(ip);
      _deviceLastSeen.remove(ip);

      Device deviceToRemove = _cachedDevices.firstWhere((d) => d.ip == ip);
      _cachedDevices.remove(deviceToRemove);
      onDeviceDisconnected!.call(deviceToRemove.name);

      _discoveryController.addError(ip);
    } catch (e) {
      print("Error removing device $ip: $e");
    }
  }

  void dispose() {
    if (!_isInitialized) return;

    _monitorTimer?.cancel();
    _monitorTimer = null;

    _tcpConnection?.dispose();
    _tcpConnection = null;

    _deviceDiscoverer?.dispose();
    _deviceDiscoverer = null;

    for (Socket socket in _tcpSockets.values) {
      socket.destroy();
    }
    _tcpSockets.clear();

    _knownIps.clear();
    _deviceLastSeen.clear();
    _cachedDevices.clear();

    if (!_discoveryController.isClosed) _discoveryController.close();

    _localIp = null;
    _deviceId = null;
    _isInitialized = false;
  }
}
