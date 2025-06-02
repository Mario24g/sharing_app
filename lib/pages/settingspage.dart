import 'package:blitzshare/l10n/l10n.dart';
import 'package:blitzshare/main.dart';
import 'package:blitzshare/services/languageservice.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    //final AppState appState = Provider.of<AppState>(context);
    final LanguageService languageService = Provider.of<LanguageService>(context);
    final Locale currentLocale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox.expand(
            child: Column(
              children: [
                PopupMenuButton<Locale>(
                  icon: Icon(Icons.language),
                  itemBuilder:
                      (context) =>
                          AppLocalizations.locals.map((locale) {
                            return PopupMenuItem<Locale>(
                              value: locale,
                              child: Row(
                                spacing: 5,
                                children: [
                                  Text(languageService.getLanguageName(locale, context)),
                                  if (currentLocale.languageCode == locale.languageCode) Icon(Icons.check, color: Colors.blue[300]),
                                ],
                              ),
                            );
                          }).toList(),
                  onSelected: (locale) => languageService.changeLanguage(context, locale),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
