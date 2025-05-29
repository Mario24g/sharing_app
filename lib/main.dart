import 'dart:async';
import 'dart:io';

import 'package:blitzshare/services/transferservice.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/pages/applicationpage.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/services/connectivityservice.dart';
import 'package:blitzshare/services/networking.dart' show NetworkService;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:blitzshare/services/notificationservice.dart';
import 'package:blitzshare/data/deviceinfo.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  //TODO: remember to remove
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (Platform.isAndroid || Platform.isIOS) {
        await NotificationService().init();
      }

      await Hive.initFlutter();
      Hive.registerAdapter(DeviceAdapter());
      Hive.registerAdapter(DevicePlatformAdapter());
      Hive.registerAdapter(HistoryEntryAdapter());
      await Hive.openBox<HistoryEntry>("history");

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
        Provider<NetworkService>(create: (_) => NetworkService(context: context)),

        //TODO: service starts only with lazy: false
        ChangeNotifierProvider<ConnectivityService>(create: (_) => ConnectivityService(), lazy: false),

        ChangeNotifierProxyProvider2<NetworkService, ConnectivityService, AppState>(
          create: (context) {
            final networkService = context.read<NetworkService>();
            final connectivityService = context.read<ConnectivityService>();
            final appState = AppState(networkService, connectivityService);
            appState.initialize();
            return appState;
          },
          update: (context, networkService, connectivityService, appState) => appState!..networkService = networkService,
        ),

        /*
        ChangeNotifierProxyProvider<NetworkService, AppState>(
          create: (context) {
            final AppState appState = AppState(context.read<NetworkService>());
            appState.initialize();
            return appState;
          },
          update: (context, networkService, appState) => appState!..networkService = networkService,
        ),
        */
        ProxyProvider<AppState, TransferService>(update: (context, appState, previous) => previous ?? TransferService(appState: appState, context: context)),
      ],
      child: MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        title: 'BlitzShare',
        darkTheme: ThemeData.dark(),
        home: const ApplicationPage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  NetworkService networkService;
  ConnectivityService connectivityService;
  final List<Device> _devices = [];
  final List<Device> _selectedDevices = [];
  final List<File> _pickedFiles = [];
  final List<File> _selectedFiles = [];
  final List<HistoryEntry> _historyEntries = [];
  final Box<HistoryEntry> _historyBox = Hive.box<HistoryEntry>("history");
  String? _deviceInfo;

  List<Device> get devices => List.unmodifiable(_devices);
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<File> get pickedFiles => List.unmodifiable(_pickedFiles);
  List<Device> get selectedDevices => List.unmodifiable(_selectedDevices);
  List<HistoryEntry> get historyEntries => List.unmodifiable(_historyEntries);
  String? get deviceInfo => _deviceInfo;

  AppState(this.networkService, this.connectivityService);

  void initialize() {
    _fetchDeviceInfo();
    _fetchHistoryEntries();
    _initializeNetworking();
  }

  void _initializeNetworking() {
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
    await _updateNetworking();

    connectivityService.addListener(_updateNetworking);
  }

  Future _updateNetworking() async {
    if (connectivityService.isWifi) {
      _deviceInfo = await DeviceInfo.getMyDeviceInfo();
      //_initializeNetworking();
    } else {
      _deviceInfo = "Unavailable";
    }
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

  void _fetchHistoryEntries() {
    _historyEntries.addAll(_historyBox.values);
    notifyListeners();
  }

  void addHistoryEntry(HistoryEntry entry) {
    _historyEntries.insert(0, entry);
    _historyBox.add(entry);
    notifyListeners();
  }

  void updateHistoryEntries(List<HistoryEntry> entries) {
    _historyEntries.clear();
    _historyBox.clear();
    _historyEntries.addAll(entries);
    _historyBox.addAll(entries);
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
