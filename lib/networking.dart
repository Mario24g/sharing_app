import 'dart:async';
import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:sharing_app/data/deviceinfo.dart';
import 'package:sharing_app/services/devicediscovery.dart';
import 'package:sharing_app/services/filereceiver.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/services/notificationservice.dart';
import 'package:sharing_app/services/tcpconnection.dart';

/*
TODO: Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  String? _localIp;
  String? _deviceId;

  final NetworkInfo _networkInfo = NetworkInfo();
  void Function(String senderIp, int senderPort)? onTransferRequest;
  void Function(String ip)? startTcpConnection;
  void Function(String message)? onFileReceived;
  void Function(String message)? onDeviceDisconnected;

  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final StreamController<Device> _discoveryController =
      StreamController.broadcast();

  Stream<Device> get discoveredDevices => _discoveryController.stream;

  final Map<String, Socket> _tcpSockets = {};

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await DeviceInfo.getDeviceInfo();

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

    FileReceiver(
      port: 8889,
      onFileReceived: onFileReceived,
    ).startReceiverServer();

    _monitorDevices();
  }

  /* TCP CONNECTION */
  void _monitorDevices() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      DateTime now = DateTime.now();

      final toRemove =
          _deviceLastSeen.entries
              .where((e) => now.difference(e.value).inSeconds > 6)
              .map((e) => e.key)
              .toList();

      for (String ip in toRemove) {
        _removeDevice(ip);
        _deviceLastSeen.remove(ip);
      }
    });
  }

  void _removeDevice(String ip) async {
    onDeviceDisconnected!("Lost connection to $ip");
    _tcpSockets[ip]?.destroy();
    _tcpSockets.remove(ip);
    _knownIps.remove(ip);
    _deviceLastSeen.remove(ip);
    _discoveryController.addError(ip);
  }
}
