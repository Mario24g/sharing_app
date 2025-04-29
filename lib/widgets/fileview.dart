import 'dart:io';
import 'dart:math';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mime/mime.dart';

class FileView extends StatelessWidget {
  final File file;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function()? onFileRemoved;

  const FileView({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onTap,
    required this.onFileRemoved,
  });

  IconData iconForMimeType(String? mime) {
    if (mime == null) return FontAwesomeIcons.question;
    if (mime.startsWith('image/')) return FontAwesomeIcons.image;
    if (mime.startsWith('video/')) return FontAwesomeIcons.video;
    if (mime.startsWith('audio/')) return FontAwesomeIcons.music;
    if (mime == 'application/pdf') return FontAwesomeIcons.filePdf;
    if (mime.startsWith('text/')) return FontAwesomeIcons.fileLines;
    return FontAwesomeIcons.file;
  }

  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const List<String> suffixes = [
      "B",
      "KB",
      "MB",
      "GB",
      "TB",
      "PB",
      "EB",
      "ZB",
      "YB",
    ];
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

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
            basename(file.path),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        leading: FaIcon(iconForMimeType(lookupMimeType(file.path))),
        trailing: ElevatedButton(
          onPressed: onFileRemoved,
          style: ButtonStyle(
            shape: WidgetStateProperty.all(CircleBorder()),
            padding: WidgetStateProperty.all(EdgeInsets.all(20)),
            backgroundColor: WidgetStateProperty.all(Colors.blue),
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.red;
              }
              return null;
            }),
          ),
          child: Icon(Icons.delete),
        ),
        subtitle: Text(formatBytes(file.lengthSync())),
        onTap: onTap,

        //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
      ),
    );
  }
}
