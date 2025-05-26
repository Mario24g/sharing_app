import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/pages/devicepage.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/device.dart';
import 'package:sharing_app/pages/historypage.dart';
import 'package:sharing_app/services/connectivityservice.dart';
import 'package:sharing_app/services/notificationservice.dart';
import 'package:sharing_app/services/transferservice.dart';
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
      final ConnectivityService connectivityService = context.read<ConnectivityService>();
      final TransferService transferService = context.read<TransferService>();

      appState.setOnTransferRequestHandler(_handleIncomingRequest);
      appState.networkService.onDeviceDisconnected = (message) {
        NotificationFlushbar.build(message).show(context);
      };
      connectivityService.addListener(() {
        final ConnectivityResult newStatus = connectivityService.currentStatus;
        final String message = switch (newStatus) {
          ConnectivityResult.mobile => "Connected via Mobile Data",
          ConnectivityResult.wifi => "Connected via Wi-Fi",
          ConnectivityResult.none => "Disconnected from Network",
          _ => "Connectivity changed",
        };

        NotificationFlushbar.build(message).show(context);
      });
      transferService.onFileReceived = (message) {
        NotificationService().showNotification(title: "File Received", body: message);
        NotificationFlushbar.build(message).show(context);
      };
      /*appState.networkService.onFileReceived = (message) {
        NotificationService().showNotification(
          title: "File Received",
          body: message,
        );
        NotificationFlushbar.build(message).show(context);
      };*/
    });
  }

  void _handleIncomingRequest(String ip) {
    final AppState appState = context.read<AppState>();
    print("Requesting device id: $ip");
    for (Device device in appState.devices) {
      print("Device in devices: ${device.ip}");
    }
    final Device requestingDevice = appState.devices.firstWhere((d) => d.ip.trim() == ip.trim());
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Incoming File Transfer"),
            content: Text("${requestingDevice.name} wants to send you a file."),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Deny")),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    final Socket socket = await Socket.connect(requestingDevice.ip, 8890);

                    socket.writeln("ACCEPT");
                    await socket.flush();
                    await socket.close();
                  } catch (e) {
                    print("Failed to notify target device: $e");
                  }
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
              BottomNavigationBarItem(icon: Icon(Icons.settings_remote_rounded), label: 'Devices'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
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
              NavigationRailDestination(icon: Icon(Icons.settings_remote_rounded), label: Text('Devices')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
              NavigationRailDestination(icon: Icon(Icons.history), label: Text('History')),
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
          ),
        );
  }

  Widget _buildCurrentPage(bool isMobile) {
    switch (_selectedIndex) {
      case 0:
        return DevicePage(isMobile: isMobile);
      case 1:
        return Scaffold();
      //return SettingsPage();
      case 2:
        return HistoryPage();
      default:
        throw UnimplementedError('No page for index $_selectedIndex');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AppState>(
          builder: (context, appState, _) {
            final deviceInfo = appState.deviceInfo;
            return Text(deviceInfo ?? "Loading...");
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
                children: [Expanded(child: ColoredBox(color: Color.fromARGB(255, 245, 245, 245), child: _buildCurrentPage(_isMobile))), _buildNavigation()],
              )
              : Row(
                children: [_buildNavigation(), Expanded(child: ColoredBox(color: Color.fromARGB(255, 245, 245, 245), child: _buildCurrentPage(_isMobile)))],
              ),
    );
  }
}
