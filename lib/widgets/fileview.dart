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
  final bool isMobile;
  final void Function()? onFileRemoved;

  const FileView({super.key, required this.file, required this.isSelected, required this.isMobile, required this.onTap, required this.onFileRemoved});

  IconData iconForMimeType(String? mime) {
    if (mime == null) return FontAwesomeIcons.question;
    if (mime.startsWith("image/")) return FontAwesomeIcons.image;
    if (mime.startsWith("video/")) return FontAwesomeIcons.video;
    if (mime.startsWith("audio/")) return FontAwesomeIcons.music;
    if (mime == "application/pdf") return FontAwesomeIcons.filePdf;
    if (mime.startsWith("text/")) return FontAwesomeIcons.fileLines;
    return FontAwesomeIcons.file;
  }

  bool isImageFile(File file) {
    final String? mime = lookupMimeType(file.path);
    return mime != null && mime.startsWith("image");
  }

  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const List<String> suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    int i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
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
              color: isSelected ? Color.fromRGBO(64, 75, 96, 0.9) : Color.fromRGBO(64, 75, 96, 0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              leading: SizedBox(
                width: 48,
                height: 48,
                child:
                    isImageFile(file)
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, color: Colors.white),
                          ),
                        )
                        : Center(child: FaIcon(iconForMimeType(lookupMimeType(file.path)), color: Colors.white)),
              ),
              title: Container(
                padding: const EdgeInsets.only(right: 12.0),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: Text(
                  basename(file.path),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: Row(children: [Expanded(flex: 4, child: Text(formatBytes(file.lengthSync()), style: TextStyle(color: Colors.white)))]),
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
                child: Icon(Icons.delete, color: Colors.white),
              ),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
