import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/pages/devicepage.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/data/deviceinfo.dart';
import 'package:sharing_app/services/notificationservice.dart';
import 'package:sharing_app/widgets/notificationflushbar.dart';

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({super.key});

  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  int _selectedIndex = 0;
  late final bool _isMobile;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isMobile = Platform.isAndroid || Platform.isIOS;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AppState appState = context.read<AppState>();
      appState.setOnTransferRequestHandler(_handleIncomingRequest);
      appState.networkService.onFileReceived = (message) {
        NotificationService().showNotification(
          title: "File Received",
          body: message,
        );
        NotificationFlushbar(message: message).show(context);
      };
      appState.networkService.onDeviceDisconnected = (message) {
        NotificationFlushbar(message: message).show(context);
      };
    });
  }

  void _handleIncomingRequest(String ip, int port) {
    final AppState appState = context.read<AppState>();
    final Device requestingDevice = appState.devices.firstWhere(
      (d) => d.ip == ip,
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Incoming File Transfer"),
            content: Text("${requestingDevice.name} wants to send you a file."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Deny"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    final Socket socket = await Socket.connect(
                      requestingDevice.ip,
                      8890,
                    );
                    /*appState.fileTransferManager.startClient(
                      requestingDevice.ip,
                    );*/

                    socket.writeln("ACCEPT");
                    await socket.flush();
                    //print("Target sent ACCEPT to ${requestingDevice.ip}");
                    await socket.close();
                  } catch (e) {
                    print("Failed to notify target device: $e");
                  }

                  /*final networkService = context.read<NetworkService>();
                  networkService.startTransferClient(ip, port);*/
                },
                child: Text("Accept"),
              ),
            ],
          ),
    );
  }

  Widget _buildNavigation() {
    return _isMobile
        ? SafeArea(
          child: BottomNavigationBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_remote_rounded),
                label: 'Devices',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        )
        : SafeArea(
          child: NavigationRail(
            extended: _isExpanded,
            labelType: NavigationRailLabelType.none,
            minWidth: 80,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.settings_remote_rounded),
                label: Text('Devices'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('History'),
              ),
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
          ),
        );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return const DevicePage();
      case 1:
        return Scaffold();
      //return const SettingsPage();
      case 2:
        return Scaffold();
      //return const HistoryPage();
      default:
        throw UnimplementedError('No page for index $_selectedIndex');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String>(
          future: DeviceInfo.getMyDeviceInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            } else if (snapshot.hasError) {
              return const Text('Error');
            } else {
              return Text("My device: ${snapshot.data}");
            }
          },
        ),
        leading:
            _isMobile
                ? null
                : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
      ),
      body:
          _isMobile
              ? Column(
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: Colors.red,
                      child: _buildCurrentPage(),
                    ),
                  ),
                  _buildNavigation(),
                ],
              )
              : Row(
                children: [
                  _buildNavigation(),
                  Expanded(
                    child: ColoredBox(
                      color: Colors.blue,
                      child: _buildCurrentPage(),
                    ),
                  ),
                ],
              ),
    );
  }
}
