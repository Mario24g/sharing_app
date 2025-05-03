import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sharing_app/model/device.dart';

class DeviceView extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback onTap;

  const DeviceView({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  /*@override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? Colors.green : null,

      child: ListTile(
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
    );
  }*/
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        elevation: 6.0,
        margin: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected
                    ? const Color.fromRGBO(64, 75, 96, 0.9)
                    : const Color.fromRGBO(64, 75, 96, 0.2),
            borderRadius: BorderRadius.circular(10.0),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 8.0,
            children: [
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              Text(
                device.ip,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.center,
              ),

              FaIcon(
                Platform.isAndroid || Platform.isIOS
                    ? FontAwesomeIcons.mobile
                    : FontAwesomeIcons.desktop,
                size: 40,
                color: Colors.white,
              ),

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
        ),
      ),
    );
  }
}
