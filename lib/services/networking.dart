import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:blitzshare/data/deviceinfo.dart';
import 'package:blitzshare/services/devicediscovery.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/services/tcpconnection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/*
TODO: Keep in mind linux ufw, android permissions and firewall
*/

class NetworkService {
  final BuildContext context;

  final NetworkInfo _networkInfo = NetworkInfo();
  void Function(String senderIp)? onTransferRequest;
  void Function()? onAccept;
  void Function(String ip)? startTcpConnection;
  void Function(String message)? onDeviceDisconnected;

  final Map<String, DateTime> _deviceLastSeen = {};
  final Set<String> _knownIps = {};
  final Map<String, Socket> _tcpSockets = {};
  final StreamController<Device> _discoveryController = StreamController.broadcast();
  String? _localIp;
  String? _deviceId;

  NetworkService({required this.context});

  Stream<Device> get discoveredDevices => _discoveryController.stream;

  Future initialize() async {
    _localIp = await _networkInfo.getWifiIP();
    _deviceId = await DeviceInfo.getDeviceInfo();

    final TCPConnection tcpConnection = TCPConnection(
      port: 8890,
      localIp: _localIp!,
      deviceLastSeen: _deviceLastSeen,
      discoveryController: _discoveryController,
      onTransferRequest: onTransferRequest,
      onAccept: onAccept,
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

    _monitorDevices();
  }

  /* TCP CONNECTION */
  void _monitorDevices() {
    Timer.periodic(Duration(seconds: 5), (timer) {
      DateTime now = DateTime.now();

      final toRemove = _deviceLastSeen.entries.where((e) => now.difference(e.value).inSeconds > 6).map((e) => e.key).toList();

      for (String ip in toRemove) {
        _removeDevice(ip, deviceDisconnected: (ip) => AppLocalizations.of(context)!.deviceDisconnected(ip));
        _deviceLastSeen.remove(ip);
      }
    });
  }

  void _removeDevice(String ip, {required String Function(String ip) deviceDisconnected}) async {
    onDeviceDisconnected!.call(deviceDisconnected(ip));
    _tcpSockets[ip]?.destroy();
    _tcpSockets.remove(ip);
    _knownIps.remove(ip);
    _deviceLastSeen.remove(ip);
    _discoveryController.addError(ip);
  }
}
