import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sharing_app/services/transferservice.dart';
import 'package:sharing_app/widgets/deviceview.dart';
import 'package:sharing_app/widgets/fileview.dart';
import 'package:sharing_app/widgets/notificationflushbar.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  bool _isTransferring = false;

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

  void _notifyTransfer(Device targetDevice) async {
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
  }

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

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<Device> deviceList = appState.devices;
    final List<File> pickedFiles = appState.pickedFiles;
    final List<File> selectedFiles = appState.selectedFiles;
    final List<Device> selectedDevices = appState.selectedDevices;
    final TransferService transferService = context.read<TransferService>();

    return SizedBox.expand(
      child: Column(
        children: [
          Expanded(
            child:
                deviceList.isEmpty
                    ? Text("No devices were found")
                    : /*ListView.builder(
                      itemCount: deviceList.length,
                      itemBuilder: (context, index) {
                        final Device device = deviceList[index];
                        final bool isSelected = selectedDevices.contains(
                          device,
                        );
                        return DeviceView(
                          device: device,
                          isSelected: isSelected,
                          onTap: () => appState.toggleDeviceSelection(device),
                        );
                      },
                    ),*/ GridView.count(
                      crossAxisCount: 5,
                      children: List.generate(deviceList.length, (index) {
                        final Device device = deviceList[index];
                        final bool isSelected = selectedDevices.contains(
                          device,
                        );
                        return DeviceView(
                          device: device,
                          isSelected: isSelected,
                          onTap: () => appState.toggleDeviceSelection(device),
                        );
                      }),
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
          ElevatedButton(
            onPressed: _isTransferring ? null : () => _pickFile(appState),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            SizedBox(height: 10),
            Text("Files for transfer"),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      _isTransferring ? null : () => appState.clearFiles(),
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
                              for (var file in List.from(selectedFiles)) {
                                appState.toggleFileSelection(file);
                              }
                            }
                          },
                  child: Text(
                    selectedFiles.isEmpty ? "Select all" : "Deselect all",
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
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
                      final List<File> updatedList = List<File>.from(
                        pickedFiles,
                      )..remove(file);
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
    );
  }
}
