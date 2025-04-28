import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sharing_app/model/device.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

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
        subtitle: Text(file.lengthSync().toString()),
        onTap: onTap,

        //trailing: Text(device['timestamp']?.split(' ')[1] ?? ''),
      ),
    );
  }
}
