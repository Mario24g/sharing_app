import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:blitzshare/data/deviceinfo.dart';
import 'package:blitzshare/services/devicediscovery.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/services/tcpconnection.dart';

/*
TODO: Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  void Function(String senderIp)? onTransferRequest;
  void Function()? onAccept;
  void Function(String ip)? startTcpConnection;
  void Function(String deviceName)? onDeviceDisconnected;

  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final Map<String, Socket> _tcpSockets = {};
  final Set<Device> _cachedDevices = {};
  final StreamController<Device> _discoveryController = StreamController.broadcast();

  String? _localIp;
  String? _deviceId;
  Timer? _monitorTimer;
  TCPConnection? _tcpConnection;
  DeviceDiscoverer? _deviceDiscoverer;

  Stream<Device> get discoveredDevices => _discoveryController.stream;

  Future initialize() async {
    try {
      _localIp = await _networkInfo.getWifiIP();
      _deviceId = await DeviceInfo.getDeviceInfo();
      _discoveryController.stream.listen((device) {
        _cachedDevices.add(device);
      });

      _tcpConnection = TCPConnection(
        port: 8890,
        localIp: _localIp!,
        deviceLastSeen: _deviceLastSeen,
        discoveryController: _discoveryController,
        onTransferRequest: onTransferRequest,
        onAccept: onAccept,
        tcpSockets: _tcpSockets,
        onConnectionLost: (ip) => _handleConnectionLost(ip),
      );
      _tcpConnection!.initialize();

      _deviceDiscoverer = DeviceDiscoverer(
        port: 8888,
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
    } catch (e) {
      print("NetworkService initialization error: $e");
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
      if (!_knownIps.contains(ip)) {
        return;
      }

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
    _monitorTimer?.cancel();
    _tcpConnection?.dispose();
    _deviceDiscoverer?.dispose();
    _discoveryController.close();
  }
}
