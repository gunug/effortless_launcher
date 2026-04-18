import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_cache.dart';
import 'deleted_apps_page.dart';
import 'models.dart';
import 'search_page.dart';
import 'unused_apps_page.dart';

const String _kLaunchHistoryKey = 'launch_history';
const String _kProtectedKey = 'protected_apps_v1';
const int _kDeletedRecordTtlMs = 365 * 24 * 60 * 60 * 1000;

void main() {
  runApp(const EffortlessLauncherApp());
}

class EffortlessLauncherApp extends StatelessWidget {
  const EffortlessLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Effortless Launcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LauncherHome(),
    );
  }
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  List<IndexedApp> _apps = [];
  Map<String, Uint8List> _icons = {};
  Map<String, int> _launchHistory = {};
  List<DeletedApp> _deletedApps = [];
  Set<String> _protectedPackages = {};
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshWithDiff());
    }
  }

  Future<void> _init() async {
    await _loadLaunchHistory();
    await _loadProtected();
    _deletedApps = await AppCache.loadDeletedApps();
    _purgeExpiredDeletedRecords();
    final cacheHit = await _loadFromCache();
    if (cacheHit) {
      unawaited(_refreshWithDiff());
    } else {
      await _loadMetadataOnly();
      unawaited(_refreshWithDiff());
    }
  }

  Future<void> _loadLaunchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLaunchHistoryKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _launchHistory = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _launchHistory = {};
    }
  }

  Future<void> _saveLaunchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLaunchHistoryKey, json.encode(_launchHistory));
  }

  Future<void> _loadProtected() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProtectedKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = json.decode(raw) as List;
      _protectedPackages = list.map((e) => e as String).toSet();
    } catch (_) {
      _protectedPackages = {};
    }
  }

  Future<void> _saveProtected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kProtectedKey, json.encode(_protectedPackages.toList()));
  }

  void _purgeExpiredDeletedRecords() {
    final cutoff = DateTime.now().millisecondsSinceEpoch - _kDeletedRecordTtlMs;
    final before = _deletedApps.length;
    _deletedApps =
        _deletedApps.where((d) => d.confirmedAt >= cutoff).toList();
    if (_deletedApps.length != before) {
      debugPrint(
          'Purged ${before - _deletedApps.length} deleted records older than 1 year');
    }
  }

  Future<bool> _loadFromCache() async {
    final meta = await AppCache.loadMeta();
    if (meta == null || meta.isEmpty) return false;
    final indexed = meta
        .map((m) => IndexedApp(
              name: m.name,
              packageName: m.packageName,
              isSystemApp: m.isSystemApp,
            ))
        .toList()
      ..sort((a, b) => a.nameLower.compareTo(b.nameLower));
    final icons = await AppCache.loadIcons([
      ...meta.map((m) => m.packageName),
      ..._deletedApps.map((d) => d.packageName),
    ]);
    if (!mounted) return true;
    setState(() {
      _apps = indexed;
      _icons = icons;
      _loading = false;
    });
    return true;
  }

  Future<void> _loadMetadataOnly() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final indexed = apps
        .map((a) => IndexedApp(
              name: a.name,
              packageName: a.packageName,
              isSystemApp: a.isSystemApp,
            ))
        .toList();
    if (!mounted) return;
    setState(() {
      _apps = indexed;
      _loading = false;
    });
    unawaited(AppCache.saveMeta(apps
        .map((a) => CachedAppMeta(a.packageName, a.name,
            isSystemApp: a.isSystemApp))
        .toList()));
  }

  Future<void> _refreshWithDiff() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final freshApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: true,
      );
      freshApps
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final previousPkgs = _apps.map((a) => a.packageName).toSet();
      final currentPkgs = freshApps.map((a) => a.packageName).toSet();
      final newlyDeleted = previousPkgs.difference(currentPkgs);

      if (newlyDeleted.isNotEmpty && _apps.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final oldByPkg = {for (final a in _apps) a.packageName: a};
        for (final pkg in newlyDeleted) {
          final already =
              _deletedApps.any((d) => d.packageName == pkg);
          if (already) continue;
          final old = oldByPkg[pkg];
          if (old == null) continue;
          _deletedApps.add(DeletedApp(
            name: old.name,
            packageName: pkg,
            confirmedAt: now,
          ));
        }
      }

      final reinstalledCount = _deletedApps.length;
      _deletedApps = _deletedApps
          .where((d) => !currentPkgs.contains(d.packageName))
          .toList();
      final reinstalledRemoved = reinstalledCount - _deletedApps.length;
      _purgeExpiredDeletedRecords();

      final indexed = freshApps
          .map((a) => IndexedApp(
                name: a.name,
                packageName: a.packageName,
                isSystemApp: a.isSystemApp,
              ))
          .toList();
      final icons = <String, Uint8List>{};
      for (final a in freshApps) {
        if (a.icon != null) icons[a.packageName] = a.icon!;
      }
      for (final d in _deletedApps) {
        final preserved = _icons[d.packageName];
        if (preserved != null) {
          icons[d.packageName] = preserved;
        }
      }

      if (!mounted) return;
      setState(() {
        _apps = indexed;
        _icons = icons;
        _loading = false;
      });

      unawaited(AppCache.saveMeta(freshApps
          .map((a) => CachedAppMeta(a.packageName, a.name,
              isSystemApp: a.isSystemApp))
          .toList()));
      unawaited(AppCache.saveIcons(icons));
      unawaited(AppCache.saveDeletedApps(_deletedApps));
      final keepIcons = {
        ...currentPkgs,
        ..._deletedApps.map((d) => d.packageName),
      };
      unawaited(AppCache.clearObsolete(keepIcons));

      if (newlyDeleted.isNotEmpty || reinstalledRemoved > 0) {
        debugPrint(
            'Refresh: ${newlyDeleted.length} newly deleted, $reinstalledRemoved reinstalled');
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _launchApp(String packageName) async {
    _launchHistory[packageName] = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
    unawaited(_saveLaunchHistory());
    await InstalledApps.startApp(packageName);
  }

  Future<void> _uninstallApps(List<String> packageNames) async {
    final filtered =
        packageNames.where((p) => !_protectedPackages.contains(p)).toList();
    for (final pkg in filtered) {
      await InstalledApps.uninstallApp(pkg);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _toggleProtect(String packageName) async {
    setState(() {
      if (_protectedPackages.contains(packageName)) {
        _protectedPackages.remove(packageName);
      } else {
        _protectedPackages.add(packageName);
      }
    });
    await _saveProtected();
  }

  Future<void> _removeDeletedRecords(List<String> packageNames) async {
    _deletedApps =
        _deletedApps.where((d) => !packageNames.contains(d.packageName)).toList();
    setState(() {});
    await AppCache.saveDeletedApps(_deletedApps);
    final currentPkgs = _apps.map((a) => a.packageName).toSet();
    final keepIcons = {
      ...currentPkgs,
      ..._deletedApps.map((d) => d.packageName),
    };
    unawaited(AppCache.clearObsolete(keepIcons));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            SearchPage(
              apps: _apps,
              icons: _icons,
              launchHistory: _launchHistory,
              loading: _loading,
              onLaunch: _launchApp,
            ),
            UnusedAppsPage(
              apps: _apps,
              icons: _icons,
              launchHistory: _launchHistory,
              protectedPackages: _protectedPackages,
              loading: _loading,
              onUninstallBatch: _uninstallApps,
              onToggleProtect: _toggleProtect,
            ),
            DeletedAppsPage(
              deletedApps: _deletedApps,
              icons: _icons,
              onRemoveRecords: _removeDeletedRecords,
            ),
          ],
        ),
      ),
    );
  }
}
