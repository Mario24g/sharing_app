import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sharing_app/services/transferservice.dart';
import 'package:sharing_app/widgets/deviceview.dart';
import 'package:sharing_app/widgets/fileview.dart';
import 'package:sharing_app/widgets/notificationflushbar.dart';

class DevicePage extends StatefulWidget {
  final bool isMobile;
  const DevicePage({super.key, required this.isMobile});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool _isTransferring = false;
  bool _isDragging = false;

  Future _pickFile(AppState appState) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select file(s)",
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null) {
      final List<File> files =
          result.files
              .where(
                (file) =>
                    file.path != null &&
                    FileSystemEntity.isFileSync(file.path!),
              )
              .map((file) => File(file.path!))
              .toList();

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

  void _startTransfer(
    List<Device> selectedDevices,
    List<File> selectedFiles,
    TransferService transferService,
  ) {
    setState(() => _isTransferring = true);

    transferService.createTransferTask(selectedDevices, selectedFiles, (
      message,
    ) {
      setState(() => _isTransferring = false);
      NotificationFlushbar.build(message).show(context);
    });
  }

  Widget _desktopPage(
    final AppState appState,
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
            flex: 9,
            child: Row(
              children: [
                /* DEVICE PANEL */
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              "Devices",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Expanded(
                              child:
                                  deviceList.isEmpty
                                      ? Text("No devices were found")
                                      : GridView.count(
                                        crossAxisCount: 2,
                                        children: List.generate(
                                          deviceList.length,
                                          (index) {
                                            final Device device =
                                                deviceList[index];
                                            final bool isSelected =
                                                selectedDevices.contains(
                                                  device,
                                                );
                                            return DeviceView(
                                              device: device,
                                              isSelected: isSelected,
                                              isMobile: widget.isMobile,
                                              onTap:
                                                  () => appState
                                                      .toggleDeviceSelection(
                                                        device,
                                                      ),
                                            );
                                          },
                                        ),
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
                          for (final DropItem item in detail.files) {
                            final String path = item.path;
                            final File file = File(path);
                            appState.addPickedFile(file);
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
                        color:
                            _isDragging
                                ? Color.fromARGB(127, 29, 27, 32)
                                : Color.fromARGB(255, 29, 27, 32),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                "Files",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),

                              SizedBox(height: 12),
                              /* CONTROL BUTTONS */
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Visibility(
                                    visible: pickedFiles.isNotEmpty,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isTransferring
                                              ? null
                                              : () => appState.clearFiles(),
                                      child: Text("Remove all"),
                                    ),
                                  ),
                                  SizedBox(width: 30),
                                  ElevatedButton(
                                    onPressed:
                                        _isTransferring
                                            ? null
                                            : () => _pickFile(appState),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.file_upload),
                                        SizedBox(width: 8),
                                        Text("Pick files"),
                                      ],
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
                                                  for (var file
                                                      in pickedFiles) {
                                                    appState
                                                        .toggleFileSelection(
                                                          file,
                                                        );
                                                  }
                                                } else {
                                                  for (var file in List.from(
                                                    selectedFiles,
                                                  )) {
                                                    appState
                                                        .toggleFileSelection(
                                                          file,
                                                        );
                                                  }
                                                }
                                              },
                                      child: Text(
                                        selectedFiles.isEmpty
                                            ? "Select all"
                                            : "Deselect all",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              pickedFiles.isEmpty
                                  ? Text("Pick or drop a file")
                                  : Expanded(
                                    child: ListView.builder(
                                      itemCount: pickedFiles.length,
                                      itemBuilder: (context, index) {
                                        final File file = pickedFiles[index];
                                        final bool isSelected = selectedFiles
                                            .contains(file);
                                        return FileView(
                                          file: file,
                                          isSelected: isSelected,
                                          onTap:
                                              () => appState
                                                  .toggleFileSelection(file),
                                          onFileRemoved: () {
                                            appState.toggleFileSelection(file);
                                            final updatedList = List<File>.from(
                                              pickedFiles,
                                            )..remove(file);
                                            appState.clearFiles();
                                            appState.addPickedFiles(
                                              updatedList,
                                            );
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

          /* TRANSFER BUTTON */
          Expanded(
            flex: 1,
            child: Center(
              child: ElevatedButton(
                onPressed:
                    (_isTransferring ||
                            selectedDevices.isEmpty ||
                            selectedFiles.isEmpty)
                        ? null
                        : () => _startTransfer(
                          selectedDevices,
                          selectedFiles,
                          transferService,
                        ),
                child:
                    _isTransferring
                        ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text("Transferring..."),
                          ],
                        )
                        : Text("Transfer"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobilePage(
    final AppState appState,
    final List<Device> deviceList,
    final List<File> pickedFiles,
    final List<File> selectedFiles,
    final List<Device> selectedDevices,
    final TransferService transferService,
  ) {
    return SizedBox.expand(
      child: Column(
        children: [
          Expanded(
            child:
                deviceList.isEmpty
                    ? Text("No devices were found")
                    : ListView.builder(
                      itemCount: deviceList.length,
                      itemBuilder: (context, index) {
                        final Device device = deviceList[index];
                        final bool isSelected = selectedDevices.contains(
                          device,
                        );
                        return DeviceView(
                          device: device,
                          isSelected: isSelected,
                          isMobile: widget.isMobile,
                          onTap: () => appState.toggleDeviceSelection(device),
                        );
                      },
                    ),
          ),
          ElevatedButton(
            onPressed:
                (_isTransferring ||
                        selectedDevices.isEmpty ||
                        selectedFiles.isEmpty)
                    ? null
                    : () => _startTransfer(
                      selectedDevices,
                      selectedFiles,
                      transferService,
                    ),
            child:
                _isTransferring
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text("Transferring..."),
                      ],
                    )
                    : Text("Transfer"),
          ),

          /* FILES */
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed:
                        _isTransferring ? null : () => _pickFile(appState),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload),
                        SizedBox(width: 8),
                        Text("Pick files"),
                      ],
                    ),
                  ),
                  if (pickedFiles.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed:
                              _isTransferring
                                  ? null
                                  : () => appState.clearFiles(),
                          child: Text("Remove all"),
                        ),
                        SizedBox(width: 30),
                        ElevatedButton(
                          onPressed:
                              _isTransferring
                                  ? null
                                  : () {
                                    if (selectedFiles.isEmpty) {
                                      for (var file in pickedFiles) {
                                        appState.toggleFileSelection(file);
                                      }
                                    } else {
                                      for (var file in List.from(
                                        selectedFiles,
                                      )) {
                                        appState.toggleFileSelection(file);
                                      }
                                    }
                                  },
                          child: Text(
                            selectedFiles.isEmpty
                                ? "Select all"
                                : "Deselect all",
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 300,
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
                              final updatedList = List<File>.from(pickedFiles)
                                ..remove(file);
                              appState.clearFiles();
                              appState.addPickedFiles(updatedList);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
        ? _mobilePage(
          appState,
          deviceList,
          pickedFiles,
          selectedFiles,
          selectedDevices,
          transferService,
        )
        : _desktopPage(
          appState,
          deviceList,
          pickedFiles,
          selectedFiles,
          selectedDevices,
          transferService,
        );
  }
}
