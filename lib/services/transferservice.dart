import 'dart:io';

import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/services/filereceiver.dart';
import 'package:blitzshare/services/filesender.dart';
import 'package:blitzshare/helper/permissionhelper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransferService {
  final AppState appState;
  FileSender? fileSender;
  FileReceiver? fileReceiver;
  late int _httpPort;
  BuildContext _context;
  void Function(String message)? onFileReceived;

  TransferService({required this.appState, required BuildContext context}) : _context = context;

  Future initialize(BuildContext context) async {
    _context = context;
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    _httpPort = sharedPreferences.getInt("httpPort") ?? 7352;

    if (Platform.isAndroid) {
      final bool hasPermissions = await PermissionHelper.hasStoragePermissions();
      if (!hasPermissions) {
        await PermissionHelper.requestStoragePermissions();
      }
    }

    await _startFileReceiver();
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
    fileSender?.dispose();

    fileSender = FileSender(port: _httpPort, appState: appState);

    try {
      TransferResult result = await fileSender!.createTransferTask(
        selectedDevices,
        selectedFiles,
        onTransferComplete,
        onProgressUpdate,
        onStatusUpdate,
        statusUpdateTransferring: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferring(filePath, deviceName),
        statusUpdateTransferred: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferred(filePath, deviceName),
        transferComplete: (fileCount, deviceCount) => AppLocalizations.of(context)!.transferComplete(fileCount, deviceCount),
        onError: onError,
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
    } catch (e) {
      onError?.call("Transfer failed: $e");
    }
  }

  Future _startFileReceiver() async {
    try {
      await fileReceiver?.stopReceiverServer();

      fileReceiver = FileReceiver(
        port: _httpPort,
        appState: appState,
        onFileReceived: (String message, Device senderDevice, List<File> files) {
          appState.addHistoryEntry(
            HistoryEntry(isUpload: false, filePaths: files.map((f) => f.path).toList(), senderDevice: senderDevice, timestamp: DateTime.now().toString()),
          );

          onFileReceived?.call(message);
        },
      );

      await fileReceiver!.startReceiverServer(
        filesReceivedMessage: (fileCount, ip) => AppLocalizations.of(_context)!.filesReceived(fileCount, ip),
        errorReceivingMessage: (deviceName) => AppLocalizations.of(_context)!.errorReceiving(deviceName),
      );
    } catch (_) {}
  }

  void cancelTransfer() {
    fileSender?.cancelTransfer();
  }

  Future dispose() async {
    fileSender?.dispose();
    await fileReceiver?.stopReceiverServer();
  }
}

class TransferResult {
  final bool success;
  final int completedFiles;
  final int totalFiles;
  final bool cancelled;
  final List<String> errors;

  TransferResult({required this.success, required this.completedFiles, required this.totalFiles, required this.cancelled, required this.errors});
}

class TransferSession {
  final int expectedFiles;
  int receivedFiles;
  final List<File> files;
  final DateTime startTime;
  DateTime lastActivity;

  TransferSession({required this.expectedFiles, required this.receivedFiles, required this.files, required this.startTime, required this.lastActivity});
}
