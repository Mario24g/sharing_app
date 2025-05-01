import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sharing_app/model/historyentry.dart';

class HistoryEntryView extends StatefulWidget {
  final HistoryEntry historyEntry;
  final void Function()? onEntryDeleted;

  int get totalDevices => historyEntry.targetDevices.length;
  int get totalFiles => historyEntry.files.length;
  /*int get totalSize =>
      files.map((f) => f.lengthSync()).fold(0, (a, b) => a + b);*/
  Future<int> getTotalSize() {
    return Future.wait<int>(
      historyEntry.files.map((f) => f.length()),
    ).then((sizes) => sizes.fold<int>(0, (a, b) => a + b));
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

  const HistoryEntryView({
    super.key,
    required this.historyEntry,
    required this.onEntryDeleted,
  });

  @override
  State<StatefulWidget> createState() => _HistoryEntryViewState();
}

class _HistoryEntryViewState extends State<HistoryEntryView> {
  @override
  Widget build(BuildContext context) {
    final bool isUpload = widget.historyEntry.isUpload;
    return ListTile(
      title: Container(
        padding: const EdgeInsets.only(right: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Text(
          isUpload ? "Upload" : "Download",
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      subtitle:
          isUpload
              ? Text("Uploaded ${widget.totalFiles} to ${widget.totalDevices}")
              : Text("Received ${widget.totalDevices} from "),
      leading: Icon(isUpload ? Icons.upload : Icons.download),
      trailing: ElevatedButton(
        onPressed: widget.onEntryDeleted,
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
    );
  }
}
