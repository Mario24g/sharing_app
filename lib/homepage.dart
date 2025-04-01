import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/devicepage.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/networking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marquee/marquee.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Discovery'),
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

/*
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
      ),
    );
  }
}
*/
/*
class AdaptiveText extends StatefulWidget {
  final String text;
  final int maxChars;
  final TextStyle? style;
  final double marqueeVelocity;
  final double blankSpace;
  final Duration pauseAfterRound;
  final bool alwaysAnimateOnMobile;

  const AdaptiveText({
    super.key,
    required this.text,
    this.maxChars = 20,
    this.style,
    this.marqueeVelocity = 30.0,
    this.blankSpace = 20.0,
    this.pauseAfterRound = const Duration(seconds: 1),
    this.alwaysAnimateOnMobile = false,
  });

  @override
  State<AdaptiveText> createState() => _AdaptiveTextState();
}

class _AdaptiveTextState extends State<AdaptiveText> {
  bool _shouldAnimate = false;
  late final bool _isMobile;
  final _marqueeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isMobile = Platform.isAndroid || Platform.isIOS;
    _shouldAnimate = _isMobile;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.text.isEmpty) return const SizedBox.shrink();

        // Get available width from parent constraints
        final availableWidth = constraints.maxWidth;

        // Return immediately if there's no space
        if (availableWidth <= 0) return const SizedBox.shrink();

        final needsMarquee = _needsMarquee(availableWidth);
        if (!needsMarquee) {
          return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }

        return _buildMarquee(availableWidth);
      },
    );
  }

  bool _needsMarquee(double maxWidth) {
    // First check character count threshold
    if (widget.text.length <= widget.maxChars) return false;

    // Then verify actual text rendering width
    try {
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      return textPainter.didExceedMaxLines;
    } catch (e) {
      // Fallback to character count if layout fails
      return widget.text.length > widget.maxChars;
    }
  }

  Widget _buildMarquee(double maxWidth) {
    return Container(
      key: _marqueeKey,
      width: maxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Double-check we have valid constraints
          if (constraints.maxWidth <= 0) {
            return Text(
              widget.text,
              style: widget.style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            );
          }

          return Marquee(
            text: widget.text,
            style: widget.style,
            velocity: _shouldAnimate ? widget.marqueeVelocity : 0,
            blankSpace: widget.blankSpace,
            pauseAfterRound: widget.pauseAfterRound,
            startPadding: 10.0,
            accelerationDuration: const Duration(seconds: 1),
            decelerationDuration: const Duration(milliseconds: 500),
          );
        },
      ),
    );
  }
}
*/
