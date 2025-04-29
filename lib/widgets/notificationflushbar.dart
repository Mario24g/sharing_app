import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

class NotificationFlushbar {
  static Flushbar build(String message) {
    return Flushbar(
      message: message,
      icon: Icon(Icons.info_outline, size: 28.0, color: Colors.blue[300]),
      margin: EdgeInsets.all(6.0),
      flushbarStyle: FlushbarStyle.FLOATING,
      flushbarPosition: FlushbarPosition.TOP,
      borderRadius: BorderRadius.circular(12),
      duration: Duration(seconds: 2),
      leftBarIndicatorColor: Colors.blue[300],
      isDismissible: true,
    );
  }
}
