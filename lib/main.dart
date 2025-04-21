import 'dart:async';

import 'package:sharing_app/homepage.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/networking.dart' show NetworkService;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:sharing_app/filetransfering.dart';

void main() {
  //TODO: remember to remove
  runZonedGuarded(
    () {
      runApp(const MainApp());
    },
    (error, stack) {
      print("Unhandled error: $error");
    },
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NetworkService>(create: (_) => NetworkService()),
        Provider<FileTransferManager>(create: (_) => FileTransferManager()),
        ChangeNotifierProxyProvider<NetworkService, AppState>(
          create: (context) => AppState(context.read<NetworkService>()),
          update: (context, networkService, appState) {
            appState ??= AppState(networkService);
            appState.initialize();
            return appState;
          },
        ),
      ],
      child: MaterialApp(
        title: 'BlitzShare',
        darkTheme: ThemeData.dark(),
        home: const ApplicationPage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier /*with WidgetsBindingObserver*/ {
  final NetworkService _networkService;
  FileTransferManager fileTransferManager = FileTransferManager();
  final List<Device> _devices = [];
  bool _isDiscovering = false;

  AppState(this._networkService);

  List<Device> get devices => List.unmodifiable(_devices);
  bool get isDiscovering => _isDiscovering;

  void initialize() {
    _networkService.initialize();
    _networkService.discoveredDevices.listen(
      (device) {
        if (!_devices.any((d) => d.ip == device.ip)) {
          _devices.add(device);
          notifyListeners();
        }
      },
      onError: (disconnectedIp) {
        _devices.removeWhere((d) => d.ip == disconnectedIp);
        notifyListeners();
      },
    );
  }

  Future startDiscovery() async {
    _isDiscovering = true;
    notifyListeners();

    await _networkService.sendDiscoveryBroadcast();

    _isDiscovering = false;
    notifyListeners();
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  Future<String> myDeviceInfo() async {
    return await _networkService.getMyDeviceInfo();
  }

  void setOnTransferRequestHandler(void Function(String ip, int port) handler) {
    _networkService.onTransferRequest = handler;
  }

  //TODO: find a way to close resources and notify disconnection
  /*@override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }*/
}
