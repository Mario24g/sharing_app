import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar_helper.dart';
import 'package:another_flushbar/flushbar_route.dart';

class NotificationFlushbar extends Flushbar {
  NotificationFlushbar({super.key, required String message})
    : super(
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
