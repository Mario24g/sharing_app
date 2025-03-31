import 'package:sharing_app/homepage.dart';
import 'package:sharing_app/networking.dart'
    show DiscoveredDevice, NetworkService, sendBroadcast;
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
        home: HomePage(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  final NetworkService _networkService;
  //final List<Map<String, String>> _devices = [];
  final List<DiscoveredDevice> _devices = [];
  bool _isDiscovering = false;

  AppState(this._networkService);

  //List<Map<String, String>> get devices => List.unmodifiable(_devices);
  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);
  bool get isDiscovering => _isDiscovering;

  void initialize() {
    _networkService.initialize();
    _networkService.discoveredDevices.listen((device) {
      /*
      if (!_devices.any((d) => d['ip'] == device['ip'])) {
        _devices.add(device);
        notifyListeners();
      }
      */
      if (!_devices.any((d) => d.ip == device.ip)) {
        _devices.add(device);
        notifyListeners();
      }
    });
  }

  Future startDiscovery() async {
    _isDiscovering = true;
    notifyListeners();

    await _networkService.sendDiscovery();

    _isDiscovering = false;
    notifyListeners();
  }

  void clearDevices() {
    _devices.clear();
    notifyListeners();
  }
}
