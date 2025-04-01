import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/networking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:marquee/marquee.dart';

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
