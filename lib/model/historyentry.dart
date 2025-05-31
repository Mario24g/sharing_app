import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:blitzshare/model/device.dart';

part 'historyentry.g.dart';

@HiveType(typeId: 0)
class HistoryEntry {
  @HiveField(0)
  final bool isUpload;
  @HiveField(1)
  final List<String> filePaths;
  @HiveField(2)
  final List<Device>? targetDevices;
  @HiveField(3)
  final Device? senderDevice;
  @HiveField(4)
  final String timestamp;

  HistoryEntry({required this.isUpload, required this.filePaths, this.targetDevices, this.senderDevice, String? timestamp})
    : timestamp = timestamp ?? DateTime.now().toString();

  List<File> get files => filePaths.map((p) => File(p)).toList();
}
