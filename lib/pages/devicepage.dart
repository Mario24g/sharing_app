import 'dart:io';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sharing_app/services/filesender.dart';
import 'package:sharing_app/widgets/deviceview.dart';
import 'package:sharing_app/widgets/fileview.dart';
import 'package:sharing_app/widgets/notificationflushbar.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final List<Device> _selectedDevices = [];

  List<File> _pickedFiles = [];
  final List<File> _selectedFiles = [];

  Future _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select file(s)",
      type: FileType.any,
      //allowedExtensions: ["png", "jpg", "jpeg"],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _pickedFiles =
            result.files
                .where((file) => file.path != null)
                .map((file) => File(file.path!))
                .toList();
        _selectedFiles.addAll(_pickedFiles);
      });
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

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<Device> deviceList = appState.devices;

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
                        bool isSelected = _selectedDevices.contains(device);
                        return DeviceView(
                          device: device,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (!_selectedDevices.contains(device)) {
                                _selectedDevices.add(device);
                                isSelected = true;
                              } else {
                                _selectedDevices.remove(device);
                                isSelected = false;
                              }
                            });
                          },
                        );
                      },
                    ),
          ),

          ElevatedButton(
            onPressed:
                _selectedDevices.isEmpty || _selectedFiles.isEmpty
                    ? null
                    : () {
                      //TODO: _notifyTransfer(_selectedDevices.first);
                      final FileSender fileSender = FileSender(port: 8889);
                      fileSender.createTransferTask(
                        _selectedDevices,
                        _selectedFiles,
                        (message) {
                          NotificationFlushbar.build(message).show(context);
                        },
                      );
                    },
            child: Text("Transfer"),
          ),

          ElevatedButton(
            onPressed: _pickFile,
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

          if (_pickedFiles.isNotEmpty) ...[
            SizedBox(height: 10),
            Text("Files for transfer"),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 30,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedFiles.clear();
                      _pickedFiles.clear();
                    });
                  },
                  child: Text("Remove all"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedFiles.isEmpty
                          ? _selectedFiles.addAll(_pickedFiles)
                          : _selectedFiles.clear();
                    });
                  },
                  child: Text(
                    _selectedFiles.isEmpty ? "Select all" : "Deselect all",
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),
            Expanded(
              child:
                  _pickedFiles.isEmpty
                      ? Text("No files were selected")
                      : ListView.builder(
                        itemCount: _pickedFiles.length,
                        itemBuilder: (context, index) {
                          final File file = _pickedFiles[index];
                          bool isSelected = _selectedFiles.contains(file);
                          return FileView(
                            file: file,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (!_selectedFiles.contains(file)) {
                                  _selectedFiles.add(file);
                                  isSelected = true;
                                } else {
                                  _selectedFiles.remove(file);
                                  isSelected = false;
                                }
                              });
                            },
                            onFileRemoved: () {
                              setState(() {
                                if (_selectedFiles.contains(file)) {
                                  _selectedFiles.remove(file);
                                }
                                _pickedFiles.remove(file);
                              });
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
