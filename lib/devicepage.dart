import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/networking.dart';
import 'package:file_picker/file_picker.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<StatefulWidget> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
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
    final appState = Provider.of<AppState>(context);

    return Column(
      children: [
        ElevatedButton(
          onPressed: appState.isDiscovering ? null : appState.startDiscovery,
          child: Text(appState.isDiscovering ? "Scanning..." : "Scan Devices"),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: appState.devices.length,
            itemBuilder: (context, index) {
              final device = appState.devices[index];
              return ListTile(
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
                trailing: FaIcon(switch (device.deviceType) {
                  DeviceType.windows => FontAwesomeIcons.windows,
                  DeviceType.linux => FontAwesomeIcons.linux,
                  DeviceType.macos => FontAwesomeIcons.apple,
                  DeviceType.android => FontAwesomeIcons.android,
                  DeviceType.ios => FontAwesomeIcons.apple,
                  DeviceType.unknown => FontAwesomeIcons.question,
                }),
                //subtitle: Text(device['ip'] ?? ''),
                //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
              );
            },
          ),
        ),

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
