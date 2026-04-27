import 'dart:async';

import 'package:flutter/services.dart';

class NotificationCountsBridge {
  static const MethodChannel _method =
      MethodChannel('com.onethelab.effortless_launcher/notifications');
  static const EventChannel _events =
      EventChannel('com.onethelab.effortless_launcher/notification_counts');

  static Future<bool> hasPermission() async {
    final r = await _method.invokeMethod<bool>('hasPermission');
    return r ?? false;
  }

  static Future<bool> openSettings() async {
    final r = await _method.invokeMethod<bool>('openSettings');
    return r ?? false;
  }

  static Future<bool> rebind() async {
    final r = await _method.invokeMethod<bool>('rebind');
    return r ?? false;
  }

  static Stream<Map<String, int>> stream() {
    return _events.receiveBroadcastStream().map((event) {
      if (event is Map) {
        final out = <String, int>{};
        event.forEach((k, v) {
          if (k is String && v is int && v > 0) out[k] = v;
        });
        return out;
      }
      return <String, int>{};
    });
  }
}
