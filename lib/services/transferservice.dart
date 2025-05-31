import 'dart:io';

import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/services/filereceiver.dart';
import 'package:blitzshare/services/filesender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
//import 'package:blitzshare/services/tcptransfer.dart';

class TransferService {
  final AppState appState;
  BuildContext _context;
  bool _receiverStarted = false;

  void Function(String message)? onFileReceived;

  /*TransferService({required this.appState, required this.context}) {
    startFileReceiver();
  }*/
  TransferService({required this.appState, required BuildContext context}) : _context = context;

  void initializeReceiver(BuildContext context) {
    if (!_receiverStarted) {
      _context = context;
      _startFileReceiver();
      _receiverStarted = true;
    }
  }

  void createTransferTask(
    BuildContext context,
    List<Device> selectedDevices,
    List<File> selectedFiles,
    void Function(String message)? onTransferComplete,
    void Function(double progress)? onProgressUpdate,
    void Function(String statusMessage)? onStatusUpdate,
  ) {
    /*final TcpFileSender sender = TcpFileSender(port: 8889);
    sender.createTransferTask(selectedDevices, selectedFiles, onTransferComplete, onProgressUpdate, onStatusUpdate);
    appState.addHistoryEntry(HistoryEntry(isUpload: true, filePaths: selectedFiles.map((f) => f.path).toList(), targetDevices: selectedDevices));*/

    FileSender(context: context).createTransferTask(
      selectedDevices,
      selectedFiles,
      onTransferComplete,
      onProgressUpdate,
      onStatusUpdate,
      statusUpdateTransferring: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferring(filePath, deviceName),
      statusUpdateTransferred: (filePath, deviceName) => AppLocalizations.of(context)!.statusUpdateTransferred(filePath, deviceName),
      transferComplete: (fileCount, deviceCount) => AppLocalizations.of(context)!.transferComplete(fileCount, deviceCount),
    );
    appState.addHistoryEntry(
      HistoryEntry(isUpload: true, filePaths: selectedFiles.map((f) => f.path).toList(), targetDevices: selectedDevices, timestamp: DateTime.now().toString()),
    );
  }

  void _startFileReceiver() async {
    /*TcpFileReceiver(
      port: 8889,
      appState: appState,
      onFileReceived: (message, device, files) {
        print("Received ${files.length} file(s) from ${device.name}");

        appState.addHistoryEntry(HistoryEntry(isUpload: false, filePaths: files.map((f) => f.path).toList(), senderDevice: device));

        onFileReceived?.call("Files received from ${device.name}");
      },
    ).startReceiverServer();*/

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
