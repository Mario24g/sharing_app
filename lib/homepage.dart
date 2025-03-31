import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Device Discovery")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: appState.isDiscovering ? null : appState.startDiscovery,
            child: Text(
              appState.isDiscovering ? "Scanning..." : "Scan Devices",
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: appState.devices.length,
              itemBuilder: (context, index) {
                final device = appState.devices[index];
                return ListTile(
                  //title: Text(device['message'] ?? 'Unknown'),
                  title: Text(device.name),

                  //subtitle: Text(device['ip'] ?? ''),
                  //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
