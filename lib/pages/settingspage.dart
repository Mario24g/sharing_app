import 'dart:io';

import 'package:blitzshare/l10n/l10n.dart';
import 'package:blitzshare/services/languageservice.dart';
import 'package:blitzshare/widgets/portinput.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as internationalization;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<Map<String, int>> _portsFuture;
  late Map<String, int> _portsValues;
  late Map<String, int> _portsRuntimeValues;
  Map<String, PortStatus> statuses = {"tcp": PortStatus.none, "udp": PortStatus.none, "http": PortStatus.none};
  Map<String, String> statusMessages = {"tcp": "", "udp": "", "http": ""};

  @override
  void initState() {
    super.initState();
    _portsFuture = _loadPorts();
  }

  Future<Map<String, int>> _loadPorts() async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();

    int tcpPort = sharedPreferences.getInt("tcpPort") ?? 7350;
    int udpPort = sharedPreferences.getInt("udpPort") ?? 7351;
    int httpPort = sharedPreferences.getInt("httpPort") ?? 7352;

    _portsRuntimeValues = {"tcp": tcpPort, "udp": udpPort, "http": httpPort};
    _portsValues = {"tcp": tcpPort, "udp": udpPort, "http": httpPort};
    return {"tcpPort": tcpPort, "udpPort": udpPort, "httpPort": httpPort};
  }

  Future _validateChanges(String portType, int portValue, BuildContext context) async {
    final bool isDuplicate = _portsValues.entries.any((entry) => entry.key != portType && entry.value == portValue);
    final bool isRuntimeUsed = _portsRuntimeValues[portType] == portValue;

    if (isRuntimeUsed) {
      setState(() {
        statuses[portType] = PortStatus.none;
        statusMessages[portType] = internationalization.AppLocalizations.of(context)!.portUsedRuntime;
      });
      return;
    }

    if (isDuplicate) {
      setState(() {
        statuses[portType] = PortStatus.error;
        statusMessages[portType] = internationalization.AppLocalizations.of(context)!.portUsedAnotherProtocol;
      });
      return;
    }

    setState(() {
      statuses[portType] = PortStatus.checking;
      statusMessages[portType] = internationalization.AppLocalizations.of(context)!.portValidating;
    });

    bool tcpValid = false, udpValid = false, httpValid = false;

    switch (portType) {
      case "tcp":
        tcpValid = await _isTCPPortAvailable(portValue);
        break;
      case "udp":
        udpValid = await _isUDPPortAvailable(portValue);
        break;
      case "http":
        httpValid = await _isHTTPPortAvailable(portValue);
        break;
    }

    final bool isValid = tcpValid || udpValid || httpValid;

    if (isValid) {
      final bool saved = await _savePort("${portType}Port", portValue);
      if (saved) {
        _portsValues[portType] = portValue;
      }
      setState(() {
        statuses[portType] = saved ? PortStatus.saved : PortStatus.error;
        statusMessages[portType] =
            saved ? internationalization.AppLocalizations.of(context)!.portSaveSuccessful : internationalization.AppLocalizations.of(context)!.portSaveFailed;
      });
    } else {
      setState(() {
        statuses[portType] = PortStatus.error;
        statusMessages[portType] = internationalization.AppLocalizations.of(context)!.portUnavailable;
      });
    }
  }

  Future<bool> _savePort(String key, int port) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(key, port);
  }

  Future<bool> _isTCPPortAvailable(int port) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final Socket socket = await Socket.connect("localhost", port);
      await socket.close();
      return false;
    } catch (e) {
      return true;
    }
  }

  Future<bool> _isUDPPortAvailable(int port) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final RawDatagramSocket socket = await RawDatagramSocket.bind("0.0.0.0", port);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isHTTPPortAvailable(int port) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
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
                  return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)));
                }

                final Map<String, int> ports = snapshot.data!;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 56,
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text("TCP", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.right),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PortInput(
                            defaultValue: ports["tcpPort"]!,
                            status: statuses["tcp"]!,
                            statusMessage: statusMessages["tcp"],
                            onChanged: (value) => _validateChanges("tcp", value.toInt(), context),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 56,
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text("UDP", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.right),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PortInput(
                            defaultValue: ports["udpPort"]!,
                            status: statuses["udp"]!,
                            statusMessage: statusMessages["udp"],
                            onChanged: (value) => _validateChanges("udp", value.toInt(), context),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 56,
                          child: Align(
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Text("HTTP", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.right),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PortInput(
                            defaultValue: ports["httpPort"]!,
                            status: statuses["http"]!,
                            statusMessage: statusMessages["http"],
                            onChanged: (value) => _validateChanges("http", value.toInt(), context),
                          ),
                        ),
                      ],
                    ),

                    Flexible(
                      child: Text(
                        internationalization.AppLocalizations.of(context)!.httpWarning,
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
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
