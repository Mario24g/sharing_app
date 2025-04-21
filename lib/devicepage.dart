import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/networking.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sharing_app/filetransfering.dart';
import 'package:sharing_app/widgets/deviceview.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  Device? _selectedDevice;
  File? _pickedFile;
  PlatformFile? _pickedPlatformFile;
  List<PlatformFile>? _pickedPlatformFiles;

  Future _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select file(s)",
      type: FileType.any,
      //allowedExtensions: ["png", "jpg", "jpeg"],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        //_pickedPlatformFiles = result.files.sublist(0);
        _pickedPlatformFile = result.files.single;
        _pickedFile = File(result.files.single.path!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<Device> deviceList = appState.devices;
    final List<bool> _selected = List.generate(deviceList.length, (i) => false);

    return Column(
      children: [
        /*ElevatedButton(
          onPressed: appState.isDiscovering ? null : appState.startDiscovery,
          child: Text(appState.isDiscovering ? "Scanning..." : "Scan Devices"),
        ),*/
        Expanded(
          child:
              deviceList.isEmpty
                  ? Text("No devices were found")
                  : ListView.builder(
                    itemCount: deviceList.length,
                    itemBuilder: (context, index) {
                      final Device device = deviceList[index];
                      final bool isSelected = _selectedDevice?.ip == device.ip;
                      return DeviceView(
                        device: device,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedDevice = device;
                          });
                        },
                      );
                    },
                  ),
        ),

        ElevatedButton(
          //onPressed: () => _fileTransferManager.startServer(_pickedFile!),
          onPressed:
              _selectedDevice == null || _pickedFile == null
                  ? null
                  : () {
                    appState.fileTransferManager.notifyTransfer(
                      _pickedFile!,
                      _selectedDevice!,
                    );
                    appState.fileTransferManager.startServer(_pickedFile!);
                  },
          child: Text("Transfer"),
        ),

        ElevatedButton(
          onPressed: _pickFile,
          child: ListTile(
            leading: Icon(Icons.file_upload, color: Colors.white),
            title: Text("Pick a file", style: TextStyle(color: Colors.white)),
          ),
        ),

        if (_pickedFile != null) ...[
          SizedBox(height: 10),
          Text(_pickedFile!.path),
          //Image.file(_pickedFile!, height: 60),
        ],
      ],
    );
  }
}
