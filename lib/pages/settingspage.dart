import 'dart:io';

import 'package:blitzshare/l10n/l10n.dart';
import 'package:blitzshare/services/languageservice.dart';
import 'package:blitzshare/widgets/portinput.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<Map<String, int>> _portsFuture;

  @override
  void initState() {
    super.initState();
    _portsFuture = _loadPorts();
  }

  Future<Map<String, int>> _loadPorts() async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

    return {
      "tcpPort": sharedPreferences.getInt("tcpPort") ?? 7350,
      "udpPort": sharedPreferences.getInt("udpPort") ?? 7351,
      "httpPort": sharedPreferences.getInt("httpPort") ?? 7352,
    };
  }

  void _validateChanges(int tcpPort, int udpPort, int httpPort) async {
    bool tcpValid = await _isTCPPortAvailable(tcpPort);
    bool udpValid = await _isUDPPortAvailable(udpPort);
    bool httpValid = await _isHTTPPortAvailable(httpPort);
    print(tcpValid);
    print(udpValid);
    print(httpValid);
    //TODO: save one by one instead
    if (tcpValid && udpValid && httpValid) _saveChanges(tcpPort, udpPort, httpPort);
  }

  void _saveChanges(int tcpPort, int udpPort, int httpPort) async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setInt("tcpPort", tcpPort);
    await sharedPreferences.setInt("udpPort", udpPort);
    await sharedPreferences.setInt("httpPort", httpPort);
    print("Saved");
  }

  Future<bool> _isTCPPortAvailable(int port) async {
    try {
      final Socket socket = await Socket.connect("localhost", port);
      await socket.close();
      return false;
    } catch (e) {
      return true;
    }
  }

  Future<bool> _isUDPPortAvailable(int port) async {
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind("0.0.0.0", port);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isHTTPPortAvailable(int port) async {
    try {
      final HttpServer httpServer = await HttpServer.bind("0.0.0.0", port);
      httpServer.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            child: FutureBuilder<Map<String, int>>(
              future: _portsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map<String, int> ports = snapshot.data!;
                int tcpPort = ports["tcpPort"]!;
                int udpPort = ports["udpPort"]!;
                int httpPort = ports["httpPort"]!;

                return Column(
                  spacing: 10,
                  children: [
                    PopupMenuButton<Locale>(
                      icon: const Icon(Icons.language),
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
                    PortInput(
                      defaultValue: ports["tcpPort"]!,
                      onChanged:
                          (value) => () {
                            tcpPort = value.toInt();
                          },
                    ),
                    PortInput(
                      defaultValue: ports["udpPort"]!,
                      onChanged:
                          (value) => () {
                            udpPort = value.toInt();
                          },
                    ),
                    PortInput(
                      defaultValue: ports["httpPort"]!,
                      onChanged:
                          (value) => () {
                            httpPort = value.toInt();
                          },
                    ),
                    ElevatedButton(onPressed: () => _validateChanges(tcpPort, udpPort, httpPort), child: Text("Save")),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
