import 'dart:io';

import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/model/historyentry.dart';
import 'package:sharing_app/services/filereceiver.dart';
import 'package:sharing_app/services/filesender.dart';

class TransferService {
  final AppState appState;

  void Function(String message)? onFileReceived;

  TransferService({required this.appState}) {
    startFileReceiver();
  }

  void createTransferTask(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
  ) {
    final FileSender fileSender = FileSender(port: 8889);
    fileSender.createTransferTask(selectedDevices, selectedFiles, onTransferComplete, onProgressUpdate, onStatusUpdate);
    appState.addHistoryEntry(HistoryEntry(isUpload: true, filePaths: selectedFiles.map((f) => f.path).toList(), targetDevices: selectedDevices));
  }

  void startFileReceiver() {
    FileReceiver(
      port: 8889,
      appState: appState,
      onFileReceived: (String message, Device senderDevice, List<File> files) {
        print("Received ${files.length} file(s) from ${senderDevice.name}");

        appState.addHistoryEntry(HistoryEntry(isUpload: false, filePaths: files.map((f) => f.path).toList(), senderDevice: senderDevice));

        onFileReceived?.call("Files received from ${senderDevice.name}");
      },
    ).startReceiverServer();
  }
}
