import 'dart:io';

import 'package:blitzshare/pages/settingspage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blitzshare/pages/devicepage.dart';
import 'package:blitzshare/main.dart';
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

      appState.networkService.onDeviceDisconnected = (message) {
        NotificationFlushbar.buildInformation(AppLocalizations.of(context)!.deviceDisconnected(message)).show(context);
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
      transferService.initialize(context);
    });
  }

  Widget _buildNavigation(BuildContext context) {
    return _isMobile
        ? SafeArea(
          child: BottomNavigationBar(
            backgroundColor: Color.fromARGB(255, 29, 27, 32),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_remote_rounded, color: Colors.white),
                label: AppLocalizations.of(context)!.navigationItemDevices,
              ),
              BottomNavigationBarItem(icon: Icon(Icons.settings, color: Colors.white), label: AppLocalizations.of(context)!.navigationItemSettings),
              BottomNavigationBarItem(icon: Icon(Icons.history, color: Colors.white), label: AppLocalizations.of(context)!.navigationItemHistory),
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
            backgroundColor: Color.fromARGB(255, 29, 27, 32),
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.settings_remote_rounded, color: Colors.white),
                label: Text(AppLocalizations.of(context)!.navigationItemDevices),
              ),
              NavigationRailDestination(icon: Icon(Icons.settings, color: Colors.white), label: Text(AppLocalizations.of(context)!.navigationItemSettings)),
              NavigationRailDestination(icon: Icon(Icons.history, color: Colors.white), label: Text(AppLocalizations.of(context)!.navigationItemHistory)),
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
        return SettingsPage();
      case 2:
        return HistoryPage();
      default:
        return DevicePage(isMobile: isMobile);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 29, 27, 32),
        title: Consumer<AppState>(
          builder: (context, appState, _) {
            final String? deviceInfo = appState.deviceInfo;
            return Text(deviceInfo ?? AppLocalizations.of(context)!.deviceInfoLoading, style: TextStyle(fontWeight: FontWeight.w500));
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
