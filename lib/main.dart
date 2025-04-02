import 'package:sharing_app/homepage.dart';
import 'package:sharing_app/networking.dart'
    show Device, NetworkService, sendBroadcast;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  final networkService = NetworkService();
  runApp(MainApp(networkService));
}

class MainApp extends StatelessWidget {
  final NetworkService networkService;
  const MainApp(this.networkService, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(networkService)..initialize(),
      child: MaterialApp(
        title: "BlitzShare",
        darkTheme: ThemeData.dark(),
        home: ApplicationPage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier /*with WidgetsBindingObserver*/ {
  final NetworkService _networkService;
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

    await _networkService.sendDiscoveryUDP();

    _isDiscovering = false;
    notifyListeners();
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }

  void myDeviceInfo() {}

  /*@override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      print("App is closing, sending DISCONNECT message...");
      _networkService.dispose();
    }
  }*/

  @override
  void dispose() {
    _networkService.dispose();
    super.dispose();
  }
}
