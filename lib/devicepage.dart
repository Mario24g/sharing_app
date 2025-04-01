import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/networking.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

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
      ],
    );
  }
}
