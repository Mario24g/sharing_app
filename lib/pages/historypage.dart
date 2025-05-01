import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharing_app/main.dart';
import 'package:sharing_app/model/historyentry.dart';
import 'package:sharing_app/widgets/historyentryview.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<StatefulWidget> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final AppState appState = Provider.of<AppState>(context);
    final List<HistoryEntry> historyEntries = appState.historyEntries;

    return SizedBox.expand(
      child: Column(
        children: [
          Expanded(
            child:
                historyEntries.isEmpty
                    ? Text("No activity yet")
                    : ListView.builder(
                      itemCount: historyEntries.length,
                      itemBuilder: (context, index) {
                        final HistoryEntry entry = historyEntries[index];
                        return HistoryEntryView(
                          historyEntry: entry,
                          onEntryDeleted: () {},
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
