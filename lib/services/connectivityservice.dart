import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  ConnectivityResult _currentStatus = ConnectivityResult.none;
  ConnectivityResult get currentStatus => _currentStatus;

  bool get isMobileData => _currentStatus == ConnectivityResult.mobile;
  bool get isWifi => _currentStatus == ConnectivityResult.wifi;
  bool get isNone => _currentStatus == ConnectivityResult.none;

  ConnectivityService() {
    _initialize();
  }

  void _initialize() async {
    final List<ConnectivityResult> resultList = await _connectivity.checkConnectivity();
    _currentStatus = resultList.firstOrNull ?? ConnectivityResult.none;
    notifyListeners();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _currentStatus = results.firstOrNull ?? ConnectivityResult.none;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
