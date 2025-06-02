import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blitzshare/main.dart';
import 'package:blitzshare/model/historyentry.dart';
import 'package:blitzshare/widgets/historyentryview.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
            spacing: 10,
            children: [
              Text(
                historyEntries.isEmpty ? AppLocalizations.of(context)!.noActivityYet : AppLocalizations.of(context)!.activity,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              if (historyEntries.isNotEmpty)
                ElevatedButton(
                  onPressed: () => appState.clearHistoryEntries(),
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Color.fromRGBO(64, 75, 96, 0.2)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.delete), SizedBox(width: 8), Text(AppLocalizations.of(context)!.clearAll)],
                  ),
                ),
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
