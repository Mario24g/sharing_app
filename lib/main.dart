import 'dart:async';
import 'dart:io';

import 'package:blitzshare/services/languageservice.dart';
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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SharedPreferences.getInstance();

    if (Platform.isAndroid || Platform.isIOS) {
      await NotificationService().init();
    }

    await Hive.initFlutter();
    Hive.registerAdapter(DeviceAdapter());
    Hive.registerAdapter(DevicePlatformAdapter());
    Hive.registerAdapter(HistoryEntryAdapter());
    await Hive.openBox<HistoryEntry>("history");

    runApp(const MainApp());
  }, (_, _) {});
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future _loadSavedLocale() async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    final String languageCode = sharedPreferences.getString("languageCode") ?? "en";
    if (mounted) {
      setState(() {
        _locale = Locale(languageCode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<NetworkService>(create: (_) => NetworkService()),

        ChangeNotifierProvider<ConnectivityService>(create: (_) => ConnectivityService(), lazy: false),

        ChangeNotifierProxyProvider2<NetworkService, ConnectivityService, AppState>(
          create: (context) {
            final NetworkService networkService = context.read<NetworkService>();
            final ConnectivityService connectivityService = context.read<ConnectivityService>();
            final AppState appState = AppState(networkService, connectivityService);
            appState.initialize();
            return appState;
          },
          update: (context, networkService, connectivityService, appState) => appState!..networkService = networkService,
        ),
        ProxyProvider<AppState, TransferService>(update: (context, appState, previous) => previous ?? TransferService(appState: appState, context: context)),

        Provider<LanguageService>(create: (_) => LanguageService()),
      ],
      child: MaterialApp(
        title: 'BlitzShare',
        locale: _locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        darkTheme: ThemeData.dark(),
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
  bool _isNetworkServiceInitialized = false;
  bool _isTransferring = false;

  List<Device> get devices => List.unmodifiable(_devices);
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<File> get pickedFiles => List.unmodifiable(_pickedFiles);
  List<Device> get selectedDevices => List.unmodifiable(_selectedDevices);
  List<HistoryEntry> get historyEntries => List.unmodifiable(_historyEntries);
  String? get deviceInfo => _deviceInfo;
  bool get isTransferring => _isTransferring;

  AppState(this.networkService, this.connectivityService);

  void initialize() {
    _fetchDeviceInfo();
    _fetchHistoryEntries();
  }

  void _initializeNetworking() async {
    if (_isNetworkServiceInitialized) return;

    try {
      await networkService.initialize();
      _isNetworkServiceInitialized = true;

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
    } catch (e) {
      _isNetworkServiceInitialized = false;
    }
  }

  void _disposeNetworking() {
    if (!_isNetworkServiceInitialized) return;

    networkService.dispose();
    _isNetworkServiceInitialized = false;

    _devices.clear();
    _selectedDevices.clear();

    notifyListeners();
  }

  Future _fetchDeviceInfo() async {
    await _updateNetworking();
    connectivityService.addListener(_updateNetworking);
  }

  Future _updateNetworking() async {
    if (connectivityService.isWifi) {
      _deviceInfo = await DeviceInfo.getMyDeviceInfo();

      if (!_isNetworkServiceInitialized) {
        _initializeNetworking();
      }
    } else {
      _deviceInfo = "";
      if (_isNetworkServiceInitialized) _disposeNetworking();
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

  void clearHistoryEntries() {
    _historyEntries.clear();
    _historyBox.clear();
    notifyListeners();
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  void setTransferring(bool isTransferring) {
    if (_isTransferring != isTransferring) {
      _isTransferring = isTransferring;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    connectivityService.removeListener(_updateNetworking);
    if (_isNetworkServiceInitialized) _disposeNetworking();

    super.dispose();
  }
}
