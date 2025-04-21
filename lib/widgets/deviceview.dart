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

  @override
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
        trailing: FaIcon(switch (device.devicePlatform) {
          DevicePlatform.windows => FontAwesomeIcons.windows,
          DevicePlatform.linux => FontAwesomeIcons.linux,
          DevicePlatform.macos => FontAwesomeIcons.apple,
          DevicePlatform.android => FontAwesomeIcons.android,
          DevicePlatform.ios => FontAwesomeIcons.apple,
          DevicePlatform.unknown => FontAwesomeIcons.question,
        }),
        subtitle: Text(device.ip),
        onTap: onTap,
        //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
      ),
    );
  }
}
