import 'dart:async';
import 'dart:io';

import 'package:sharing_app/pages/applicationpage.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/networking.dart' show NetworkService;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:sharing_app/services/notificationservice.dart';

void main() {
  //TODO: remember to remove
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (!Platform.isWindows) await NotificationService().init();
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

class AppState extends ChangeNotifier {
  final NetworkService networkService;
  final List<Device> _devices = [];

  AppState(this.networkService);

  List<Device> get devices => List.unmodifiable(_devices);

  void initialize() {
    networkService.initialize();
    networkService.discoveredDevices.listen(
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

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  void setOnTransferRequestHandler(void Function(String ip, int port) handler) {
    networkService.onTransferRequest = handler;
  }
}
