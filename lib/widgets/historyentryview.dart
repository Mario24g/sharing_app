import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HistoryEntryView extends StatefulWidget {
  final HistoryEntry historyEntry;
  final DateFormat format = DateFormat('dd/MM/yyyy HH:mm');
  final void Function()? onEntryDeleted;

  int get totalDevices => historyEntry.targetDevices?.length ?? 0;
  int get totalFiles => historyEntry.files.length;
  String get senderDevice => historyEntry.senderDevice?.name ?? "unknown";
  String get timestamp => format.format(DateTime.parse(historyEntry.timestamp));
  /*int get totalSize =>
      files.map((f) => f.lengthSync()).fold(0, (a, b) => a + b);*/
  Future<int> getTotalSize() {
    return Future.wait<int>(historyEntry.files.map((f) => f.length())).then((sizes) => sizes.fold<int>(0, (a, b) => a + b));
  }

  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const List<String> suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    int i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  HistoryEntryView({super.key, required this.historyEntry, required this.onEntryDeleted});

  @override
  State<StatefulWidget> createState() => _HistoryEntryViewState();
}

class _HistoryEntryViewState extends State<HistoryEntryView> {
  @override
  Widget build(BuildContext context) {
    final bool isUpload = widget.historyEntry.isUpload;
    final AppLocalizations? localizations = AppLocalizations.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(color: Color.fromRGBO(64, 75, 96, 0.2), borderRadius: BorderRadius.circular(12.0)),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              leading: SizedBox(
                width: 48,
                height: 48,
                child: isUpload ? Icon(Icons.upload, color: Colors.blue[300]) : Icon(Icons.download, color: Colors.red[300]),
              ),
              title: Container(
                padding: const EdgeInsets.only(right: 12.0),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: Text(
                  isUpload ? localizations!.historyEntrySendTitle(widget.timestamp) : localizations!.historyEntryReceiveTitle(widget.timestamp),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      isUpload
                          ? localizations.historyEntrySendSubtitle(widget.totalFiles, widget.totalDevices)
                          : localizations.historyEntryReceiveSubtitle(widget.totalFiles, widget.senderDevice),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
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
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
