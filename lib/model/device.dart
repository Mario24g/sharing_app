import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'device.g.dart';

@HiveType(typeId: 1)
class Device {
  @HiveField(0)
  final String ip;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final DevicePlatform devicePlatform;
  @HiveField(3)
  final String timestamp = DateTime.now().toString();

  Device({required this.ip, required this.name, required this.devicePlatform});

  String getDeviceType() {
    final display = PlatformDispatcher.instance.views.first.display;
    return display.size.shortestSide / display.devicePixelRatio < 600 ? "phone" : "tablet";
  }
}

@HiveType(typeId: 2)
enum DevicePlatform {
  @HiveField(0)
  windows,
  @HiveField(1)
  linux,
  @HiveField(2)
  macos,
  @HiveField(3)
  android,
  @HiveField(4)
  ios,
  @HiveField(5)
  unknown,
}
