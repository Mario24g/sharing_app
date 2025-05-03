import 'package:flutter/foundation.dart';

class Device {
  final String ip;
  final String name;
  final DevicePlatform devicePlatform;
  final String timestamp = DateTime.now().toString();

  Device({required this.ip, required this.name, required this.devicePlatform});

  String getDeviceType() {
    final display = PlatformDispatcher.instance.views.first.display;
    return display.size.shortestSide / display.devicePixelRatio < 600
        ? "phone"
        : "tablet";
  }
}

enum DevicePlatform { windows, linux, macos, android, ios, unknown }
