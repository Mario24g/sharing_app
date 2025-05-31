import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blitzshare/pages/devicepage.dart';
import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/device.dart';
import 'package:blitzshare/pages/historypage.dart';
import 'package:blitzshare/services/connectivityservice.dart';
import 'package:blitzshare/services/notificationservice.dart';
import 'package:blitzshare/services/transferservice.dart';
import 'package:blitzshare/widgets/notificationflushbar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        NotificationFlushbar.buildInformation(message).show(context);
      };
      connectivityService.addListener(() {
        final ConnectivityResult newStatus = connectivityService.currentStatus;
        switch (newStatus) {
          case ConnectivityResult.mobile:
            NotificationFlushbar.buildWarning(AppLocalizations.of(context)!.connectedMobile).show(context);
            break;
          case ConnectivityResult.wifi:
            NotificationFlushbar.buildInformation(AppLocalizations.of(context)!.connectedWifi).show(context);
            break;
          case ConnectivityResult.none:
            NotificationFlushbar.buildError(AppLocalizations.of(context)!.disconnected).show(context);
            break;
          case _:
            break;
        }
      });
      transferService.onFileReceived = (message) {
        NotificationService().showNotification(title: AppLocalizations.of(context)!.fileReceived, body: message);
        NotificationFlushbar.buildInformation(message).show(context);
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

  //TODO: IMPLEMENT
  void _handleIncomingRequest(String ip) {
    final AppState appState = context.read<AppState>();
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

  Widget _buildNavigation(BuildContext context) {
    return _isMobile
        ? SafeArea(
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(icon: Icon(Icons.settings_remote_rounded), label: AppLocalizations.of(context)!.navigationItemDevices),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: AppLocalizations.of(context)!.navigationItemSettings),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: AppLocalizations.of(context)!.navigationItemHistory),
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
            destinations: [
              NavigationRailDestination(icon: Icon(Icons.settings_remote_rounded), label: Text(AppLocalizations.of(context)!.navigationItemDevices)),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text(AppLocalizations.of(context)!.navigationItemSettings)),
              NavigationRailDestination(icon: Icon(Icons.history), label: Text(AppLocalizations.of(context)!.navigationItemHistory)),
            ],
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
          ),
        );
  }

  Widget _buildCurrentPage(bool isMobile) {
    switch (_selectedIndex) {
      case 0:
        print("DevicePage built");
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
            return Text(deviceInfo ?? AppLocalizations.of(context)!.deviceInfoLoading);
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
                  Expanded(child: ColoredBox(color: Color.fromARGB(255, 245, 245, 245), child: _buildCurrentPage(_isMobile))),
                  _buildNavigation(context),
                ],
              )
              : Row(
                children: [
                  _buildNavigation(context),
                  Expanded(child: ColoredBox(color: Color.fromARGB(255, 245, 245, 245), child: _buildCurrentPage(_isMobile))),
                ],
              ),
    );
  }
}
