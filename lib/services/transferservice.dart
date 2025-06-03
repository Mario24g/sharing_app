import 'dart:io';

import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/services/filereceiver.dart';
import 'package:blitzshare/services/filesender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransferService {
  final AppState appState;
  late FileSender fileSender;
  late int _httpPort;
  BuildContext _context;

  void Function(String message)? onFileReceived;

  TransferService({required this.appState, required BuildContext context}) : _context = context;

  void initialize(BuildContext context) async {
    _context = context;

    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    _httpPort = sharedPreferences.getInt("httpPort") ?? 7352;

    _startFileReceiver();
  }

  void createTransferTask(
    BuildContext context,
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
    void Function(String error)? onError,
  ) async {
    fileSender = FileSender(port: _httpPort, context: context);
    TransferResult result = await fileSender.createTransferTask(
      selectedDevices,
      selectedFiles,
      onTransferComplete,
      onProgressUpdate,
      onStatusUpdate,
      onError,
      statusUpdateTransferring: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferring(filePath, deviceName),
      statusUpdateTransferred: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferred(filePath, deviceName),
      transferComplete: (fileCount, deviceCount) => AppLocalizations.of(context)!.transferComplete(fileCount, deviceCount),
      transferFailed: () => AppLocalizations.of(context)!.transferFailed,
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
      port: _httpPort,
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

  TransferResult({required this.success, required this.completedFiles, required this.totalFiles, required this.cancelled});

  double get completionPercentage => totalFiles > 0 ? completedFiles / totalFiles : 0.0;
}
