import 'dart:async';
import 'dart:io';

import 'package:sharing_app/model/historyentry.dart';
import 'package:sharing_app/pages/applicationpage.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/services/networking.dart' show NetworkService;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:sharing_app/services/notificationservice.dart';
import 'package:sharing_app/services/transferservice.dart';
import 'package:sharing_app/data/deviceinfo.dart';

void main() {
  //TODO: remember to remove
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (Platform.isAndroid || Platform.isIOS) {
        await NotificationService().init();
      }
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
          create: (context) {
            final AppState appState = AppState(context.read<NetworkService>());
            appState.initialize();
            return appState;
          },
          update:
              (context, networkService, appState) =>
                  appState!..networkService = networkService,
        ),

        ProxyProvider<AppState, TransferService>(
          update:
              (context, appState, previous) =>
                  previous ?? TransferService(appState: appState),
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
  NetworkService networkService;
  final List<Device> _devices = [];
  final List<Device> _selectedDevices = [];
  final List<File> _pickedFiles = [];
  final List<File> _selectedFiles = [];
  final List<HistoryEntry> _historyEntries = [];
  String? _deviceInfo;

  List<Device> get devices => List.unmodifiable(_devices);
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<File> get pickedFiles => List.unmodifiable(_pickedFiles);
  List<Device> get selectedDevices => List.unmodifiable(_selectedDevices);
  List<HistoryEntry> get historyEntries => List.unmodifiable(_historyEntries);
  String? get deviceInfo => _deviceInfo;

  AppState(this.networkService);

  void initialize() {
    /*_devices.addAll(
      List.of([
        Device(ip: "123", name: "Test", devicePlatform: DevicePlatform.windows),
        Device(ip: "123", name: "Test2", devicePlatform: DevicePlatform.macos),
        Device(ip: "123", name: "Test2", devicePlatform: DevicePlatform.linux),
        Device(
          ip: "123",
          name: "Test2",
          devicePlatform: DevicePlatform.android,
        ),
      ]),
    );*/
    _fetchDeviceInfo();
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
        _selectedDevices.removeWhere((d) => d.ip == disconnectedIp);
        notifyListeners();
      },
    );
  }

  Future _fetchDeviceInfo() async {
    _deviceInfo = await DeviceInfo.getMyDeviceInfo();
    notifyListeners();
  }

  void addPickedFile(File file) {
    _pickedFiles.add(file);
    _selectedFiles.add(file);
    notifyListeners();
  }

  void addPickedFiles(List<File> files) {
    _pickedFiles.addAll(files);
    _selectedFiles.addAll(files);
    notifyListeners();
  }

  void toggleFileSelection(File file) {
    if (_selectedFiles.contains(file)) {
      _selectedFiles.remove(file);
    } else {
      _selectedFiles.add(file);
    }
    notifyListeners();
  }

  void clearFiles() {
    _pickedFiles.clear();
    _selectedFiles.clear();
    notifyListeners();
  }

  void toggleDeviceSelection(Device device) {
    if (_selectedDevices.contains(device)) {
      _selectedDevices.remove(device);
    } else {
      _selectedDevices.add(device);
    }
    notifyListeners();
  }

  void addHistoryEntry(HistoryEntry entry) {
    _historyEntries.insert(0, entry);
    notifyListeners();
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  void setOnTransferRequestHandler(void Function(String ip) handler) {
    networkService.onTransferRequest = handler;
  }

  void setOnAcceptHandler(void Function() handler) {
    networkService.onAccept = handler;
  }
}
