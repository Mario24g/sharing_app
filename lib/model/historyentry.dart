import 'dart:io';

import 'package:sharing_app/model/device.dart';

class HistoryEntry {
  final bool isUpload;
  final List<File> files;
  final List<Device> targetDevices;
  final Device? senderDevice;
  final String timestamp = DateTime.now().toString();

  HistoryEntry({
    required this.isUpload,
    required this.files,
    required this.targetDevices,
    this.senderDevice,
  });
}
