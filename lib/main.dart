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
  List<Device> _selectedDevices = [];
  List<File> _selectedFiles = [];

  List<Device> get selectedDevices => _selectedDevices;
  List<File> get selectedFiles => _selectedFiles;
  List<Device> get devices => List.unmodifiable(_devices);

  AppState(this.networkService);

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

  void updateSelectedDevices(List<Device> devices) {
    //_selectedDevices.addAll(devices);
    _selectedDevices = devices;
    notifyListeners();
  }

  void updateSelectedFiles(List<File> files) {
    //_selectedFiles.addAll(files);
    _selectedFiles = files;
    notifyListeners();
  }

  void clearSelections() {
    _selectedDevices.clear();
    _selectedFiles.clear();
    notifyListeners();
  }

  void setOnTransferRequestHandler(void Function(String ip) handler) {
    networkService.onTransferRequest = handler;
  }

  void setOnAcceptHandler(void Function() handler) {
    networkService.onAccept = handler;
  }
}
