import 'dart:io';

import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/model/historyentry.dart';
import 'package:sharing_app/services/filereceiver.dart';
import 'package:sharing_app/services/filesender.dart';

class TransferService {
  final AppState appState;

  void Function(String message)? onFileReceived;

  TransferService({required this.appState});

  void createTransferTask(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
  ) {
    final FileSender fileSender = FileSender(port: 8889);
    fileSender.createTransferTask(
      selectedDevices,
      selectedFiles,
      onTransferComplete,
    );
    appState.addHistoryEntry(
      HistoryEntry(
        isUpload: true,
        files: selectedFiles,
        targetDevices: selectedDevices,
      ),
    );
  }

  void startFileReceiver() {
    FileReceiver(
      port: 8889,
      onFileReceived: onFileReceived,
    ).startReceiverServer();
  }

  void receiveFiles({required List<File> files, required Device senderDevice}) {
    appState.addHistoryEntry(
      HistoryEntry(isUpload: false, files: files, senderDevice: senderDevice),
    );
  }
}
