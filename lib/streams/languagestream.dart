import 'dart:async';

import 'package:intl/locale.dart';

class GeneralStreams {
  const GeneralStreams._();

  static StreamController<Locale> languageStream = StreamController.broadcast();
}
