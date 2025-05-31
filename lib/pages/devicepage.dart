import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blitzshare/services/transferservice.dart';
import 'package:blitzshare/widgets/deviceview.dart';
import 'package:blitzshare/widgets/fileview.dart';
import 'package:blitzshare/widgets/notificationflushbar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DevicePage extends StatefulWidget {
  final bool isMobile;
  const DevicePage({super.key, required this.isMobile});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool _isTransferring = false;
  bool _isDragging = false;
  double _progress = 0.0;
  String _statusMessage = "";

  Future _pickFile(AppState appState) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: AppLocalizations.of(context)!.selectFiles,
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null) {
      bool hasDirectories = result.files.any((file) => file.path != null && FileSystemEntity.isDirectorySync(file.path!));
      if (hasDirectories) {
        if (mounted) {
          NotificationFlushbar.buildWarning(AppLocalizations.of(context)!.foldersNotAllowed).show(context);
        }
      }

      final List<File> files =
          result.files.where((file) => file.path != null && FileSystemEntity.isFileSync(file.path!)).map((file) => File(file.path!)).toList();

      appState.addPickedFiles(files);
    }
  }

  /*void _notifyTransfer(Device targetDevice) async {
    final NetworkInfo networkInfo = NetworkInfo();
    final String localIp = await networkInfo.getWifiIP() ?? '0.0.0.0';
    final String notification = "NOTIFICATION:$localIp";

    try {
      final Socket socket = await Socket.connect(targetDevice.ip, 8890);

      socket.writeln(notification);
      await socket.flush();
      await socket.close();
    } catch (e) {
      print("Failed to notify target device: $e");
    }
  }*/

  void _startTransfer(AppState appState, BuildContext context, List<Device> selectedDevices, List<File> selectedFiles, TransferService transferService) {
    setState(() {
      _isTransferring = true;
      _progress = 0.0;
      _statusMessage = "";
    });

    double lastProgress = 0.0;
    DateTime lastUpdate = DateTime.now();

    void onPerFileProgress(double newProgress) {
      const double threshold = 0.01;
      final DateTime now = DateTime.now();

      if ((newProgress - lastProgress).abs() >= threshold || now.difference(lastUpdate) > const Duration(milliseconds: 100)) {
        lastProgress = newProgress;
        lastUpdate = now;

        setState(() {
          _progress = newProgress;
        });
      }
    }

    transferService.createTransferTask(
      context,
      selectedDevices,
      selectedFiles,
      (message) {
        setState(() {
          _isTransferring = false;
          _progress = 0.0;
          _statusMessage = "";
        });
        NotificationFlushbar.buildInformation(message).show(context);
      },
      onPerFileProgress,
      (statusMessage) {
        setState(() {
          _statusMessage = statusMessage;
        });
      },
    );
    for (File file in List.from(selectedFiles)) {
      appState.toggleFileSelection(file);
    }
  }

  void _cancelTransfer(TransferService transferService) {
    transferService.fileSender.cancelTransfer();
    setState(() {
      _isTransferring = false;
    });
  }

  Widget _desktopPage(
    final AppState appState,
    final BuildContext context,
    final List<Device> deviceList,
    final List<File> pickedFiles,
    final List<File> selectedFiles,
    final List<Device> selectedDevices,
    final TransferService transferService,
  ) {
    return SizedBox.expand(
      child: Column(
        children: [
          /* PANELS */
          Expanded(
            flex: 8,
            child: Row(
              children: [
                /* DEVICE PANEL */
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(AppLocalizations.of(context)!.devices, style: Theme.of(context).textTheme.bodyMedium),
                            Expanded(
                              child:
                                  deviceList.isEmpty
                                      ? Text(AppLocalizations.of(context)!.noDevicesFound)
                                      : GridView.count(
                                        crossAxisCount: 2,
                                        children: List.generate(deviceList.length, (index) {
                                          final Device device = deviceList[index];
                                          final bool isSelected = selectedDevices.contains(device);
                                          return DeviceView(
                                            device: device,
                                            isSelected: isSelected,
                                            isMobile: widget.isMobile,
                                            onTap: () => appState.toggleDeviceSelection(device),
                                          );
                                        }),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                /* FILE PANEL */
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropTarget(
                      onDragDone: (detail) {
                        setState(() {
                          bool isAnyDirectory = detail.files.any((item) {
                            return !FileSystemEntity.isFileSync(item.path);
                          });
                          if (isAnyDirectory) {
                            NotificationFlushbar.buildWarning(AppLocalizations.of(context)!.foldersNotAllowed).show(context);
                          }

                          for (final DropItem item in detail.files) {
                            final String path = item.path;
                            final File file = File(path);
                            bool isFile = FileSystemEntity.isFileSync(file.path);
                            if (isFile) appState.addPickedFile(file);
                          }
                        });
                      },
                      onDragEntered: (detail) {
                        setState(() {
                          _isDragging = true;
                        });
                      },
                      onDragExited: (detail) {
                        setState(() {
                          _isDragging = false;
                        });
                      },
                      child: Card(
                        color: _isDragging ? Color.fromARGB(127, 29, 27, 32) : Color.fromARGB(255, 29, 27, 32),
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(AppLocalizations.of(context)!.files, style: Theme.of(context).textTheme.bodyMedium),

                              SizedBox(height: 12),
                              /* CONTROL BUTTONS */
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Visibility(
                                    visible: pickedFiles.isNotEmpty,
                                    child: ElevatedButton(
                                      onPressed: _isTransferring ? null : () => appState.clearFiles(),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [Icon(Icons.delete), SizedBox(width: 8), Text(AppLocalizations.of(context)!.clearAll)],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                  ElevatedButton(
                                    onPressed: _isTransferring ? null : () => _pickFile(appState),
                                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [Icon(Icons.upload_file), SizedBox(width: 8), Text(AppLocalizations.of(context)!.pickFiles)],
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                  Visibility(
                                    visible: pickedFiles.isNotEmpty,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isTransferring
                                              ? null
                                              : () {
                                                if (selectedFiles.isEmpty) {
                                                  for (File file in pickedFiles) {
                                                    appState.toggleFileSelection(file);
                                                  }
                                                } else {
                                                  for (File file in List.from(selectedFiles)) {
                                                    appState.toggleFileSelection(file);
                                                  }
                                                }
                                              },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(selectedFiles.isEmpty ? Icons.select_all : Icons.deselect),
                                          SizedBox(width: 8),
                                          Text(selectedFiles.isEmpty ? AppLocalizations.of(context)!.selectAll : AppLocalizations.of(context)!.deselectAll),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              pickedFiles.isEmpty
                                  ? Text(AppLocalizations.of(context)!.pickDropFile)
                                  : Expanded(
                                    child: ListView.builder(
                                      itemCount: pickedFiles.length,
                                      itemBuilder: (context, index) {
                                        final File file = pickedFiles[index];
                                        final bool isSelected = selectedFiles.contains(file);
                                        return FileView(
                                          file: file,
                                          isSelected: isSelected,
                                          onTap: () => appState.toggleFileSelection(file),
                                          onFileRemoved: () {
                                            appState.toggleFileSelection(file);
                                            final updatedList = List<File>.from(pickedFiles)..remove(file);
                                            appState.clearFiles();
                                            appState.addPickedFiles(updatedList);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /* CONTROL BUTTONS */
          //TODO
          Expanded(
            flex: 2,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Visibility(
                      visible: _isTransferring,
                      child: Text(_statusMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                    ),
                    Visibility(
                      visible: _isTransferring,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: _progress, minHeight: 8, backgroundColor: Colors.grey[300], color: Colors.lightBlueAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Row(
                      spacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed:
                              (_isTransferring || selectedDevices.isEmpty || selectedFiles.isEmpty)
                                  ? null
                                  : () => _startTransfer(appState, context, selectedDevices, selectedFiles, transferService),
                          child:
                              _isTransferring
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                      SizedBox(width: 8),
                                      Text(AppLocalizations.of(context)!.transferring),
                                    ],
                                  )
                                  : Text(AppLocalizations.of(context)!.transfer),
                        ),

                        ElevatedButton(onPressed: (_isTransferring) ? () => _cancelTransfer(transferService) : null, child: Text("Cancel")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobilePage(
    final AppState appState,
    final BuildContext context,
    final List<Device> deviceList,
    final List<File> pickedFiles,
    final List<File> selectedFiles,
    final List<Device> selectedDevices,
    final TransferService transferService,
  ) {
    const double minHeight = 150;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            /* DEVICES */
            SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(AppLocalizations.of(context)!.devices, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        deviceList.isEmpty
                            ? Text(AppLocalizations.of(context)!.noDevicesFound)
                            : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  deviceList.map((device) {
                                    final isSelected = selectedDevices.contains(device);
                                    return DeviceView(
                                      device: device,
                                      isSelected: isSelected,
                                      isMobile: true,
                                      onTap: () => appState.toggleDeviceSelection(device),
                                    );
                                  }).toList(),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            /* FILES */
            SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: _isDragging ? const Color.fromARGB(127, 29, 27, 32) : const Color.fromARGB(255, 29, 27, 32),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(AppLocalizations.of(context)!.files, style: Theme.of(context).textTheme.titleMedium),
                        /* CONTROL BUTTONS */
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (pickedFiles.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.delete),
                                tooltip: AppLocalizations.of(context)!.clearFiles,
                                onPressed: _isTransferring ? null : () => appState.clearFiles(),
                              ),
                            IconButton(
                              icon: Icon(Icons.upload_file),
                              tooltip: AppLocalizations.of(context)!.pickFiles,
                              onPressed: _isTransferring ? null : () => _pickFile(appState),
                            ),
                            if (pickedFiles.isNotEmpty)
                              IconButton(
                                icon: Icon(selectedFiles.isEmpty ? Icons.select_all : Icons.deselect),
                                tooltip: selectedFiles.isEmpty ? AppLocalizations.of(context)!.selectAll : AppLocalizations.of(context)!.deselectAll,
                                onPressed:
                                    _isTransferring
                                        ? null
                                        : () {
                                          if (selectedFiles.isEmpty) {
                                            for (File file in pickedFiles) {
                                              appState.toggleFileSelection(file);
                                            }
                                          } else {
                                            for (File file in List.from(selectedFiles)) {
                                              appState.toggleFileSelection(file);
                                            }
                                          }
                                        },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        pickedFiles.isEmpty
                            ? Text(AppLocalizations.of(context)!.noFilesSelected)
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pickedFiles.length,
                              itemBuilder: (context, index) {
                                final file = pickedFiles[index];
                                final isSelected = selectedFiles.contains(file);
                                return FileView(
                                  file: file,
                                  isSelected: isSelected,
                                  onTap: () => appState.toggleFileSelection(file),
                                  onFileRemoved: () {
                                    appState.toggleFileSelection(file);
                                    final updatedList = List<File>.from(pickedFiles)..remove(file);
                                    appState.clearFiles();
                                    appState.addPickedFiles(updatedList);
                                  },
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            /* TRANSFER BUTTON */
            Visibility(
              visible: _isTransferring,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusMessage, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _progress, minHeight: 6, backgroundColor: Colors.grey[700], color: Colors.blueAccent),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Row(
                spacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        (_isTransferring || selectedDevices.isEmpty || selectedFiles.isEmpty)
                            ? null
                            : () => _startTransfer(appState, context, selectedDevices, selectedFiles, transferService),
                    icon: _isTransferring ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.send),
                    label: Text(_isTransferring ? AppLocalizations.of(context)!.transferring : AppLocalizations.of(context)!.transfer),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isTransferring ? () => _cancelTransfer(transferService) : null,
                    icon: Icon(Icons.cancel_outlined),
                    label: Text("Cancel"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<Device> deviceList = appState.devices;
    final List<File> pickedFiles = appState.pickedFiles;
    final List<File> selectedFiles = appState.selectedFiles;
    final List<Device> selectedDevices = appState.selectedDevices;
    final TransferService transferService = context.read<TransferService>();

    return widget.isMobile
        ? _mobilePage(appState, context, deviceList, pickedFiles, selectedFiles, selectedDevices, transferService)
        : _desktopPage(appState, context, deviceList, pickedFiles, selectedFiles, selectedDevices, transferService);
  }
}
