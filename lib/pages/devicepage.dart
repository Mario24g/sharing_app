import 'dart:io';

import 'package:blitzshare/services/connectivityservice.dart';
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
  //bool _isTransferring = false;
  bool _isDragging = false;
  bool _isFilePickerActive = false;
  double _progress = 0.0;
  String _statusMessage = "";

  Future _pickFile(AppState appState) async {
    if (_isFilePickerActive) return;

    _isFilePickerActive = true;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: AppLocalizations.of(context)!.selectFiles,
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null) {
        bool hasDirectories = result.files.any((file) => file.path != null && FileSystemEntity.isDirectorySync(file.path!));

        if (hasDirectories && mounted) {
          NotificationFlushbar.buildWarning(AppLocalizations.of(context)!.foldersNotAllowed).show(context);
        }

        final List<File> files =
            result.files.where((file) => file.path != null && FileSystemEntity.isFileSync(file.path!)).map((file) => File(file.path!)).toList();

        appState.addPickedFiles(files);
      }
    } catch (_) {
    } finally {
      _isFilePickerActive = false;
    }
  }

  void _startTransfer(AppState appState, BuildContext context, List<Device> selectedDevices, List<File> selectedFiles, TransferService transferService) {
    appState.setTransferring(true);
    setState(() {
      //_isTransferring = true;
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
      (completionMessage) {
        setState(() {
          //_isTransferring = false;
          appState.setTransferring(false);
          _progress = 0.0;
          _statusMessage = "";
        });
        NotificationFlushbar.buildInformation(completionMessage).show(context);
      },
      onPerFileProgress,
      (statusMessage) {
        setState(() {
          _statusMessage = statusMessage;
        });
      },
      (error) {
        setState(() {
          //_isTransferring = false;
          appState.setTransferring(false);
          _progress = 0.0;
          _statusMessage = "";
        });
      },
    );
    for (File file in List.from(selectedFiles)) {
      appState.toggleFileSelection(file);
    }
  }

  void _cancelTransfer(TransferService transferService, AppState appState) {
    transferService.fileSender!.cancelTransfer();
    setState(() {
      //_isTransferring = false;
      appState.setTransferring(false);
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
    final ConnectivityService connectivityService,
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
                            Text(AppLocalizations.of(context)!.devices, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            Expanded(
                              child:
                                  deviceList.isEmpty
                                      ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        spacing: 10,
                                        children: [
                                          connectivityService.isMobileData
                                              ? Text(AppLocalizations.of(context)!.notAvailableWithMobileData)
                                              : Text(AppLocalizations.of(context)!.noDevicesFound),
                                          if (!connectivityService.isMobileData)
                                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                                        ],
                                      )
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
                              Text(AppLocalizations.of(context)!.files, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),

                              SizedBox(height: 12),
                              /* CONTROL BUTTONS */
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  spacing: 10,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Visibility(
                                      visible: pickedFiles.isNotEmpty,
                                      child: ElevatedButton(
                                        onPressed: appState.isTransferring ? null : () => appState.clearFiles(),
                                        style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Color.fromRGBO(64, 75, 96, 0.2)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [Icon(Icons.delete), SizedBox(width: 8), Text(AppLocalizations.of(context)!.clearAll)],
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: appState.isTransferring ? null : () => _pickFile(appState),
                                      style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Color.fromRGBO(64, 75, 96, 0.2)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [Icon(Icons.upload_file), SizedBox(width: 8), Text(AppLocalizations.of(context)!.pickFiles)],
                                      ),
                                    ),
                                    Visibility(
                                      visible: pickedFiles.isNotEmpty,
                                      child: ElevatedButton(
                                        onPressed:
                                            appState.isTransferring
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
                                        style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Color.fromRGBO(64, 75, 96, 0.2)),
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
                                          isMobile: false,
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
                      visible: appState.isTransferring,
                      child: Text(_statusMessage, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)),
                    ),
                    Visibility(
                      visible: appState.isTransferring,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: _progress, minHeight: 8, backgroundColor: Colors.grey[300], color: Colors.lightBlueAccent),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    IntrinsicWidth(
                      child: Row(
                        spacing: 10,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed:
                                (appState.isTransferring || selectedDevices.isEmpty || selectedFiles.isEmpty)
                                    ? null
                                    : () => _startTransfer(appState, context, selectedDevices, selectedFiles, transferService),
                            style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Color.fromRGBO(64, 75, 96, 0.2)),
                            child:
                                appState.isTransferring
                                    ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                                        ),
                                        SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)!.transferring),
                                      ],
                                    )
                                    : Text(AppLocalizations.of(context)!.transfer),
                          ),

                          if (appState.isTransferring)
                            ElevatedButton(
                              onPressed: (appState.isTransferring) ? () => _cancelTransfer(transferService, appState) : null,
                              style: ButtonStyle(
                                shape: WidgetStateProperty.all(CircleBorder()),
                                padding: WidgetStateProperty.all(EdgeInsets.all(20)),
                                backgroundColor: WidgetStateProperty.all(Colors.red),
                                overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (states.contains(WidgetState.pressed)) {
                                    return Colors.red;
                                  }
                                  return null;
                                }),
                              ),
                              child: Icon(Icons.cancel_schedule_send_rounded, color: Colors.white),
                            ),
                        ],
                      ),
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
    final ConnectivityService connectivityService,
  ) {
    const double minHeight = 150;
    return Stack(
      children: [
        SingleChildScrollView(
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
                                ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 10,
                                  children: [
                                    connectivityService.isMobileData
                                        ? Text(AppLocalizations.of(context)!.notAvailableWithMobileData)
                                        : Text(AppLocalizations.of(context)!.noDevicesFound),
                                    if (!connectivityService.isMobileData) CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                                  ],
                                )
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

                SizedBox(height: 12),

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
                                    onPressed: appState.isTransferring ? null : () => appState.clearFiles(),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.upload_file),
                                  tooltip: AppLocalizations.of(context)!.pickFiles,
                                  onPressed: appState.isTransferring ? null : () => _pickFile(appState),
                                ),
                                if (pickedFiles.isNotEmpty)
                                  IconButton(
                                    icon: Icon(selectedFiles.isEmpty ? Icons.select_all : Icons.deselect),
                                    tooltip: selectedFiles.isEmpty ? AppLocalizations.of(context)!.selectAll : AppLocalizations.of(context)!.deselectAll,
                                    onPressed:
                                        appState.isTransferring
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

                            SizedBox(height: 8),

                            pickedFiles.isEmpty
                                ? Text(AppLocalizations.of(context)!.noFilesSelected)
                                : ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: pickedFiles.length,
                                  itemBuilder: (context, index) {
                                    final File file = pickedFiles[index];
                                    final bool isSelected = selectedFiles.contains(file);
                                    return FileView(
                                      file: file,
                                      isSelected: isSelected,
                                      isMobile: true,
                                      onTap: () => appState.toggleFileSelection(file),
                                      onFileRemoved: () {
                                        appState.toggleFileSelection(file);
                                        final List<File> updatedList = List<File>.from(pickedFiles)..remove(file);
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

                SizedBox(height: appState.isTransferring ? 120 : 80),
              ],
            ),
          ),
        ),

        /* TRANSFER CONTROLS */
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            elevation: 8,
            child: Container(
              padding: EdgeInsets.all(12),
              color: Color.fromARGB(255, 29, 27, 32),
              child: Column(
                children: [
                  if (appState.isTransferring)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusMessage, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
                        SizedBox(height: 4),
                        LinearProgressIndicator(value: _progress, minHeight: 8, backgroundColor: Colors.grey[300], color: Colors.blue),
                        SizedBox(height: 8),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              (appState.isTransferring || selectedDevices.isEmpty || selectedFiles.isEmpty)
                                  ? null
                                  : () => _startTransfer(appState, context, selectedDevices, selectedFiles, transferService),
                          icon:
                              appState.isTransferring
                                  ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), strokeWidth: 2),
                                  )
                                  : Icon(Icons.send),
                          label: Text(appState.isTransferring ? AppLocalizations.of(context)!.transferring : AppLocalizations.of(context)!.transfer),
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.all(14), foregroundColor: Colors.white, backgroundColor: Colors.blue),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: appState.isTransferring ? () => _cancelTransfer(transferService, appState) : null,
                          icon: Icon(Icons.cancel_schedule_send_sharp),
                          label: Text("Cancel"),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14), foregroundColor: Colors.white, backgroundColor: Colors.red[300]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final ConnectivityService connectivityService = context.read<ConnectivityService>();
    final List<Device> deviceList = appState.devices;
    final List<File> pickedFiles = appState.pickedFiles;
    final List<File> selectedFiles = appState.selectedFiles;
    final List<Device> selectedDevices = appState.selectedDevices;
    final TransferService transferService = context.read<TransferService>();

    return widget.isMobile
        ? _mobilePage(appState, context, deviceList, pickedFiles, selectedFiles, selectedDevices, transferService, connectivityService)
        : _desktopPage(appState, context, deviceList, pickedFiles, selectedFiles, selectedDevices, transferService, connectivityService);
  }
}
