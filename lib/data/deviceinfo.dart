import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DeviceInfo {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getMyDeviceInfo() async {
    final String? localIp = await NetworkInfo().getWifiIP();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return "${androidInfo.model} $localIp";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await _deviceInfo.iosInfo;
      return "${iosDeviceInfo.modelName} $localIp";
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
      return "${windowsInfo.computerName} $localIp";
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await _deviceInfo.linuxInfo;
      return "${linuxDeviceInfo.prettyName} $localIp";
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await _deviceInfo.macOsInfo;
      return "${macOsDeviceInfo.modelName} $localIp";
    }
    return "Unknown device $localIp";
  }

  static Future<String> getDeviceInfo() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
      return "${androidInfo.model}|android";
    } else if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await _deviceInfo.iosInfo;
      return "${iosDeviceInfo.modelName}|ios";
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await _deviceInfo.windowsInfo;
      return "${windowsInfo.computerName}|windows";
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxDeviceInfo = await _deviceInfo.linuxInfo;
      return "${linuxDeviceInfo.prettyName}|linux";
    } else if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await _deviceInfo.macOsInfo;
      return "${macOsDeviceInfo.modelName}|macos";
    }
    return "Unknown device|unknown";
  }
}
