import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/networking.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sharing_app/filetransfering.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  Device? _selectedDevice;
  File? _pickedFile;
  PlatformFile? _pickedPlatformFile;

  Future _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select file",
      type: FileType.any,
      //allowedExtensions: ["png", "jpg", "jpeg"],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
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
        ElevatedButton(
          onPressed: appState.isDiscovering ? null : appState.startDiscovery,
          child: Text(appState.isDiscovering ? "Scanning..." : "Scan Devices"),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: deviceList.length,
            itemBuilder: (context, index) {
              final Device device = deviceList[index];
              final bool isSelected = _selectedDevice?.ip == device.ip;
              return Container(
                color: isSelected ? Colors.green : null,

                child: ListTile(
                  title: Container(
                    padding: const EdgeInsets.only(right: 12.0),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Text(
                      device.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  trailing: FaIcon(switch (device.devicePlatform) {
                    DevicePlatform.windows => FontAwesomeIcons.windows,
                    DevicePlatform.linux => FontAwesomeIcons.linux,
                    DevicePlatform.macos => FontAwesomeIcons.apple,
                    DevicePlatform.android => FontAwesomeIcons.android,
                    DevicePlatform.ios => FontAwesomeIcons.apple,
                    DevicePlatform.unknown => FontAwesomeIcons.question,
                  }),
                  subtitle: Text(device.ip),
                  onTap: () {
                    setState(() {
                      _selectedDevice = device;
                      //_selectedDevice == null ? device : null;
                    });
                  },
                  //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
                ),
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

        /*ElevatedButton(
          onPressed:
              () => _fileTransferManager.startClient(_selectedDevice!.ip),
          child: Text("Client"),
        ),*/
        ElevatedButton(
          onPressed: _pickFile,
          child: ListTile(
            leading: Icon(Icons.image, color: Colors.white),
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
