import "package:blitzshare/main.dart";
import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class LanguageService {
  static const List<Locale> locales = [Locale("en"), Locale("es"), Locale("zh"), Locale("ru")];

  String getLanguageName(Locale locale, BuildContext context) {
    switch (locale.languageCode) {
      case "en":
        return "English";
      case "es":
        return "Español";
      case "zh":
        return "中文";
      case "ru":
        return "Русский";
      default:
        return locale.languageCode;
    }
  }

  void changeLanguage(BuildContext context, Locale newLocale) async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString("languageCode", newLocale.languageCode);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainApp()));
    }
  }
}
