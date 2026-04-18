import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedAppMeta {
  final String packageName;
  final String name;

  const CachedAppMeta(this.packageName, this.name);

  Map<String, dynamic> toJson() => {'p': packageName, 'n': name};

  static CachedAppMeta fromJson(Map<String, dynamic> j) =>
      CachedAppMeta(j['p'] as String, j['n'] as String);
}

class AppCache {
  static const String _metaKey = 'app_cache_meta_v1';
  static Directory? _iconDir;

  static Future<Directory> _dir() async {
    final cached = _iconDir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final d = Directory('${support.path}/icon_cache');
    if (!await d.exists()) await d.create(recursive: true);
    _iconDir = d;
    return d;
  }

  static String _fileName(String packageName) {
    final sanitized = packageName.replaceAll(RegExp(r'[^\w.-]'), '_');
    return '$sanitized.bin';
  }

  static Future<List<CachedAppMeta>?> loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = json.decode(raw) as List;
      return list
          .map((e) => CachedAppMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMeta(List<CachedAppMeta> apps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _metaKey,
      json.encode(apps.map((a) => a.toJson()).toList()),
    );
  }

  static Future<Map<String, Uint8List>> loadIcons(
      Iterable<String> packageNames) async {
    final dir = await _dir();
    final result = <String, Uint8List>{};
    for (final pkg in packageNames) {
      final file = File('${dir.path}/${_fileName(pkg)}');
      if (await file.exists()) {
        try {
          result[pkg] = await file.readAsBytes();
        } catch (_) {}
      }
    }
    return result;
  }

  static Future<void> saveIcons(Map<String, Uint8List> icons) async {
    final dir = await _dir();
    for (final entry in icons.entries) {
      final file = File('${dir.path}/${_fileName(entry.key)}');
      try {
        await file.writeAsBytes(entry.value, flush: false);
      } catch (_) {}
    }
  }

  static Future<void> clearObsolete(Set<String> currentPackages) async {
    final dir = await _dir();
    final keepFiles = currentPackages.map(_fileName).toSet();
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!keepFiles.contains(name)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
