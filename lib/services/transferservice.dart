import 'dart:io';

import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/services/filereceiver.dart';
import 'package:blitzshare/services/filesender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TransferService {
  final AppState appState;
  late FileSender fileSender;
  BuildContext _context;

  void Function(String message)? onFileReceived;

  TransferService({required this.appState, required BuildContext context}) : _context = context;

  void initializeReceiver(BuildContext context) {
    _context = context;
    _startFileReceiver();
  }

  void createTransferTask(
    BuildContext context,
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
  ) async {
    fileSender = FileSender(context: context);
    TransferResult result = await fileSender.createTransferTask(
      selectedDevices,
      selectedFiles,
      onTransferComplete,
      onProgressUpdate,
      onStatusUpdate,
      statusUpdateTransferring: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferring(filePath, deviceName),
      statusUpdateTransferred: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferred(filePath, deviceName),
      transferComplete: (fileCount, deviceCount) => AppLocalizations.of(context)!.transferComplete(fileCount, deviceCount),
    );
    if (result.success) {
      appState.addHistoryEntry(
        HistoryEntry(
          isUpload: true,
          filePaths: selectedFiles.map((f) => f.path).toList(),
          targetDevices: selectedDevices,
          timestamp: DateTime.now().toString(),
        ),
      );
    }
  }

  void _startFileReceiver() async {
    FileReceiver(
      port: 8889,
      appState: appState,
      context: _context,
      onFileReceived: (String message, Device senderDevice, List<File> files) {
        appState.addHistoryEntry(
          HistoryEntry(isUpload: false, filePaths: files.map((f) => f.path).toList(), senderDevice: senderDevice, timestamp: DateTime.now().toString()),
        );
        onFileReceived?.call(message);
      },
    ).startReceiverServer(
      filesReceivedMessage: (fileCount, ip) => AppLocalizations.of(_context)!.filesReceived(fileCount, ip),
      errorReceivingMessage: (deviceName) => AppLocalizations.of(_context)!.errorReceiving(deviceName),
    );
  }
}

class TransferSession {
  final int expectedFiles;
  int receivedFiles;
  final List<File> files;

  TransferSession({required this.expectedFiles, required this.receivedFiles, required this.files});
}

class TransferResult {
  final bool success;
  final int completedFiles;
  final int totalFiles;
  final bool cancelled;
  final List<String> errors;

  TransferResult({required this.success, required this.completedFiles, required this.totalFiles, required this.cancelled, required this.errors});

  double get completionPercentage => totalFiles > 0 ? completedFiles / totalFiles : 0.0;

  bool get hasErrors => errors.isNotEmpty;
}
