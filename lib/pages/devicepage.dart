import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
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
                      final FileSender fileSender = FileSender(port: 8889);
                      fileSender.createTransferTask(
                        _selectedDevices,
                        _selectedFiles,
                        (message) {
                          NotificationFlushbar(message: message).show(context);
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
