import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:blitzshare/model/device.dart';

class DeviceView extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isMobile;

  const DeviceView({super.key, required this.device, required this.isSelected, required this.onTap, required this.isMobile});

  Widget _desktopView(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        elevation: 6.0,
        margin: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color.fromRGBO(64, 75, 96, 0.9) : const Color.fromRGBO(64, 75, 96, 0.2),
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.all(12.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /* HEADER */
                  Column(
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(device.ip, style: const TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
                    ],
                  ),

                  /* ICONS */
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      FaIcon(
                        switch (device.devicePlatform) {
                          DevicePlatform.windows || DevicePlatform.linux || DevicePlatform.macos => FontAwesomeIcons.desktop,
                          DevicePlatform.android ||
                          DevicePlatform.ios => device.getDeviceType() == "tablet" ? FontAwesomeIcons.tablet : FontAwesomeIcons.mobile,
                          DevicePlatform.unknown => FontAwesomeIcons.question,
                        },
                        size: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      FaIcon(
                        switch (device.devicePlatform) {
                          DevicePlatform.windows => FontAwesomeIcons.windows,
                          DevicePlatform.linux => FontAwesomeIcons.linux,
                          DevicePlatform.macos => FontAwesomeIcons.apple,
                          DevicePlatform.android => FontAwesomeIcons.android,
                          DevicePlatform.ios => FontAwesomeIcons.apple,
                          DevicePlatform.unknown => FontAwesomeIcons.question,
                        },
                        size: 20,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _mobileView(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color.fromRGBO(64, 75, 96, 0.9) : const Color.fromRGBO(64, 75, 96, 0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              title: Container(
                padding: const EdgeInsets.only(right: 12.0),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: Text(device.name, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              leading: FaIcon(switch (device.devicePlatform) {
                DevicePlatform.windows => FontAwesomeIcons.windows,
                DevicePlatform.linux => FontAwesomeIcons.linux,
                DevicePlatform.macos => FontAwesomeIcons.apple,
                DevicePlatform.android => FontAwesomeIcons.android,
                DevicePlatform.ios => FontAwesomeIcons.apple,
                DevicePlatform.unknown => FontAwesomeIcons.question,
              }),
              subtitle: Text(device.ip),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isMobile ? _mobileView(context) : _desktopView(context);
  }
}
