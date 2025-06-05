import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          Map<Permission, PermissionStatus> statuses = await [Permission.photos, Permission.videos, Permission.audio].request();

          return statuses.values.every((status) => status.isGranted);
        } else if (androidInfo.version.sdkInt >= 30) {
          if (await Permission.manageExternalStorage.isGranted) {
            return true;
          }

          final PermissionStatus status = await Permission.manageExternalStorage.request();
          if (status.isGranted) {
            return true;
          }

          Map<Permission, PermissionStatus> statuses = await [Permission.storage].request();

          return statuses.values.every((status) => status.isGranted);
        } else {
          //Android 10 and below
          Map<Permission, PermissionStatus> statuses = await [Permission.storage].request();

          return statuses.values.every((status) => status.isGranted);
        }
      }
    } catch (e) {
      print("Error requesting storage permissions: $e");
    }

    return false;
  }

  static Future<bool> hasStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          return await Permission.photos.isGranted && await Permission.videos.isGranted && await Permission.audio.isGranted;
        } else if (androidInfo.version.sdkInt >= 30) {
          return await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted;
        } else {
          return await Permission.storage.isGranted;
        }
      }
    } catch (e) {
      print('Error checking storage permissions: $e');
    }

    return false;
  }
}
