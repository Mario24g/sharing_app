class Device {
  final String ip;
  final String name;
  final DevicePlatform devicePlatform;
  final String timestamp = DateTime.now().toString();

  Device({required this.ip, required this.name, required this.devicePlatform});
}

enum DevicePlatform { windows, linux, macos, android, ios, unknown }
