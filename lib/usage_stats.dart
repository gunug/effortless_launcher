import 'package:flutter/services.dart';

class UsageStatsBridge {
  static const MethodChannel _channel =
      MethodChannel('com.onethelab.effortless_launcher/usage_stats');

  static Future<bool> hasPermission() async {
    final r = await _channel.invokeMethod<bool>('hasPermission');
    return r ?? false;
  }

  static Future<bool> openSettings() async {
    final r = await _channel.invokeMethod<bool>('openSettings');
    return r ?? false;
  }

  static Future<Map<String, List<int>>> queryEvents({
    int days = 30,
    int maxPerPackage = 50,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'queryEvents',
        {'days': days, 'maxPerPackage': maxPerPackage},
      );
      if (raw == null) return {};
      return raw.map((k, v) {
        final list = (v as List).map((e) => (e as num).toInt()).toList();
        return MapEntry(k as String, list);
      });
    } catch (_) {
      return {};
    }
  }
}
