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

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(historyEntries.isEmpty ? "No activity yet" : "Activity", style: Theme.of(context).textTheme.bodyMedium),
              Expanded(
                child: ListView.builder(
                  itemCount: historyEntries.length,
                  itemBuilder: (context, index) {
                    final HistoryEntry entry = historyEntries[index];
                    return HistoryEntryView(
                      historyEntry: entry,
                      onEntryDeleted: () {
                        final updatedList = List<HistoryEntry>.from(historyEntries)..remove(entry);
                        appState.updateHistoryEntries(updatedList);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
