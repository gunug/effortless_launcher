import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_cache.dart';
import 'deleted_apps_page.dart';
import 'donation_iap.dart';
import 'hot_zone_page.dart';
import 'models.dart';
import 'notification_counts.dart';
import 'search_page.dart';
import 'unused_apps_page.dart';
import 'usage_stats.dart';

const String _kLaunchLogKey = 'launch_log_v1';
const String _kLegacyLaunchHistoryKey = 'launch_history';
const String _kProtectedKey = 'protected_apps_v1';
const String _kLastPageKey = 'last_page_index_v1';
const String _kInstalledAtKey = 'installed_at_v1';
const String _kHiddenRecentKey = 'hidden_recent_v1';
const String _kWarmupStateKey = 'warmup_state_v1';
const String _kNotifPromptShownKey = 'notif_prompt_shown_v1';
const int _kDeletedRecordTtlMs = 365 * 24 * 60 * 60 * 1000;
const int _kMaxLaunchesPerApp = 50;
const int _kHotZonePageIndex = 0;
const int _kSearchPageIndex = 1;
const int _kUnusedPageIndex = 2;
const int _kWarmupDays = 30;

const EventChannel _kPackageEventChannel =
    EventChannel('com.onethelab.effortless_launcher/package_events');
const Duration _kPackageEventDebounce = Duration(milliseconds: 300);

enum _WarmupState { initial, pending, done, skipped }

_WarmupState _warmupStateFromString(String? raw) {
  switch (raw) {
    case 'pending':
      return _WarmupState.pending;
    case 'done':
      return _WarmupState.done;
    case 'skipped':
      return _WarmupState.skipped;
    default:
      return _WarmupState.initial;
  }
}

String _warmupStateToString(_WarmupState s) {
  switch (s) {
    case _WarmupState.initial:
      return 'initial';
    case _WarmupState.pending:
      return 'pending';
    case _WarmupState.done:
      return 'done';
    case _WarmupState.skipped:
      return 'skipped';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DonationPurchaseHandler.instance.start();
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
  PageController? _pageController;
  int _unusedPageVisits = 0;
  List<IndexedApp> _apps = [];
  Map<String, Uint8List> _icons = {};
  Map<String, List<int>> _launchLog = {};
  Map<String, int> _installedAt = {};
  List<DeletedApp> _deletedApps = [];
  Set<String> _protectedPackages = {};
  Set<String> _hiddenRecent = {};
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshPending = false;
  StreamSubscription<dynamic>? _packageEventSub;
  Timer? _packageEventDebounce;
  StreamSubscription<Map<String, int>>? _notifCountsSub;
  Map<String, int> _notifCounts = {};
  _WarmupState _warmupState = _WarmupState.initial;
  bool _warmupCheckInFlight = false;
  bool _firstRunPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribePackageEvents();
    _subscribeNotificationCounts();
    _preinit();
  }

  @override
  void dispose() {
    _packageEventDebounce?.cancel();
    _packageEventSub?.cancel();
    _notifCountsSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController?.dispose();
    super.dispose();
  }

  void _subscribePackageEvents() {
    _packageEventSub =
        _kPackageEventChannel.receiveBroadcastStream().listen((event) {
      _packageEventDebounce?.cancel();
      _packageEventDebounce = Timer(_kPackageEventDebounce, () {
        unawaited(_refreshWithDiff());
      });
    }, onError: (Object err) {
      debugPrint('package event channel error: $err');
    });
  }

  void _subscribeNotificationCounts() {
    _notifCountsSub = NotificationCountsBridge.stream().listen((counts) {
      if (!mounted) return;
      setState(() => _notifCounts = counts);
    }, onError: (Object err) {
      debugPrint('notification counts error: $err');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshWithDiff());
      unawaited(_checkPendingWarmup());
    }
  }

  Future<void> _preinit() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_kLastPageKey) ?? _kSearchPageIndex;
    final initialPage =
        (saved == _kHotZonePageIndex || saved == _kSearchPageIndex)
            ? saved
            : _kSearchPageIndex;
    _pageController = PageController(initialPage: initialPage);
    if (!mounted) return;
    setState(() {});
    await _init();
  }

  Future<void> _init() async {
    await _loadLaunchLog();
    await _loadProtected();
    await _loadInstalledAt();
    await _loadHiddenRecent();
    await _loadWarmupState();
    _deletedApps = await AppCache.loadDeletedApps();
    _purgeExpiredDeletedRecords();
    final cacheHit = await _loadFromCache();
    if (cacheHit) {
      unawaited(_refreshWithDiff());
    } else {
      await _loadMetadataOnly();
      unawaited(_refreshWithDiff());
    }
    unawaited(_maybePromptFirstRun());
  }

  Future<void> _loadWarmupState() async {
    final prefs = await SharedPreferences.getInstance();
    _warmupState = _warmupStateFromString(prefs.getString(_kWarmupStateKey));
  }

  Future<void> _saveWarmupState(_WarmupState state) async {
    _warmupState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWarmupStateKey, _warmupStateToString(state));
  }

  Future<void> _maybePromptFirstRun() async {
    if (!mounted) return;
    if (_firstRunPromptShown) return;
    if (_warmupState != _WarmupState.initial) {
      unawaited(_maybePromptNotificationAccess());
      return;
    }
    if (_launchLog.isNotEmpty) {
      await _saveWarmupState(_WarmupState.skipped);
      unawaited(_maybePromptNotificationAccess());
      return;
    }
    _firstRunPromptShown = true;
    final accepted = await _showWarmupDialog();
    if (!mounted) return;
    if (accepted) {
      await _saveWarmupState(_WarmupState.pending);
      final opened = await UsageStatsBridge.openSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Usage Access settings')),
        );
      }
    } else {
      await _saveWarmupState(_WarmupState.skipped);
      unawaited(_maybePromptNotificationAccess());
    }
  }

  Future<bool> _showWarmupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Set up Hot Zone instantly'),
        content: const Text(
          'Effortless can use your recent app activity (last 30 days) to '
          'pre-fill Hot Zone right away, instead of waiting a week or two for it to learn.\n\n'
          'You will be sent to Android Settings to grant Usage Access. '
          'You can skip this and Hot Zone will warm up over time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Set up'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _checkPendingWarmup() async {
    if (_warmupState != _WarmupState.pending) return;
    if (_warmupCheckInFlight) return;
    _warmupCheckInFlight = true;
    try {
      final granted = await UsageStatsBridge.hasPermission();
      if (!granted) return;
      final events = await UsageStatsBridge.queryEvents(
        days: _kWarmupDays,
        maxPerPackage: _kMaxLaunchesPerApp,
      );
      if (events.isEmpty) {
        await _saveWarmupState(_WarmupState.done);
        unawaited(_maybePromptNotificationAccess());
        return;
      }
      final imported = _mergeWarmupIntoLaunchLog(events);
      await _saveLaunchLog();
      await _saveWarmupState(_WarmupState.done);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported recent activity for $imported apps'),
          ),
        );
      }
      unawaited(_maybePromptNotificationAccess());
    } finally {
      _warmupCheckInFlight = false;
    }
  }

  int _mergeWarmupIntoLaunchLog(Map<String, List<int>> events) {
    var imported = 0;
    events.forEach((pkg, timestamps) {
      if (timestamps.isEmpty) return;
      final existing = _launchLog[pkg] ?? <int>[];
      final merged = <int>{...existing, ...timestamps}.toList()..sort((a, b) => b.compareTo(a));
      final capped = merged.length > _kMaxLaunchesPerApp
          ? merged.sublist(0, _kMaxLaunchesPerApp)
          : merged;
      _launchLog[pkg] = capped;
      imported++;
    });
    return imported;
  }

  Future<void> _maybePromptNotificationAccess() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kNotifPromptShownKey) == true) return;
    final granted = await NotificationCountsBridge.hasPermission();
    if (granted) {
      await prefs.setBool(_kNotifPromptShownKey, true);
      return;
    }
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Show notification badges'),
        content: const Text(
          'See unread notification counts on app icons. '
          'You will be sent to Android Settings to enable Notification Access.\n\n'
          'You can skip and enable this later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    await prefs.setBool(_kNotifPromptShownKey, true);
    if (accepted == true) {
      final opened = await NotificationCountsBridge.openSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not open Notification Access settings')),
        );
      }
    }
  }

  Future<void> _loadLaunchLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLaunchLogKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        _launchLog = decoded.map((k, v) => MapEntry(
              k,
              (v as List).map((e) => (e as num).toInt()).toList(),
            ));
        return;
      } catch (_) {
        _launchLog = {};
      }
    }
    final oldRaw = prefs.getString(_kLegacyLaunchHistoryKey);
    if (oldRaw != null && oldRaw.isNotEmpty) {
      try {
        final decoded = json.decode(oldRaw) as Map<String, dynamic>;
        _launchLog = decoded.map(
            (k, v) => MapEntry(k, <int>[(v as num).toInt()]));
        await _saveLaunchLog();
      } catch (_) {
        _launchLog = {};
      }
    }
  }

  Future<void> _saveLaunchLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLaunchLogKey, json.encode(_launchLog));
  }

  Future<void> _saveLastPage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastPageKey, index);
  }

  Map<String, int> _deriveLastLaunchMap() {
    final m = <String, int>{};
    _launchLog.forEach((k, v) {
      if (v.isNotEmpty) m[k] = v.first;
    });
    return m;
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

  Future<void> _loadInstalledAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kInstalledAtKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _installedAt = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _installedAt = {};
    }
  }

  Future<void> _saveInstalledAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstalledAtKey, json.encode(_installedAt));
  }

  Future<void> _loadHiddenRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHiddenRecentKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = json.decode(raw) as List;
      _hiddenRecent = list.map((e) => e as String).toSet();
    } catch (_) {
      _hiddenRecent = {};
    }
  }

  Future<void> _saveHiddenRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kHiddenRecentKey, json.encode(_hiddenRecent.toList()));
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
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshPending = false;
        await _runRefreshOnce();
      } while (_refreshPending && mounted);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _runRefreshOnce() async {
    final freshApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: true,
    );
    freshApps
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final previousPkgs = _apps.map((a) => a.packageName).toSet();
      final currentPkgs = freshApps.map((a) => a.packageName).toSet();
      final newlyDeleted = previousPkgs.difference(currentPkgs);

      final hasBaseline = _installedAt.isNotEmpty;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var installedAtChanged = false;
      for (final pkg in currentPkgs) {
        if (!_installedAt.containsKey(pkg)) {
          _installedAt[pkg] = hasBaseline ? nowMs : 0;
          installedAtChanged = true;
        }
      }
      final installedAtKeys = _installedAt.keys.toList();
      for (final pkg in installedAtKeys) {
        if (!currentPkgs.contains(pkg)) {
          _installedAt.remove(pkg);
          installedAtChanged = true;
        }
      }
      if (installedAtChanged) {
        unawaited(_saveInstalledAt());
      }

      final hiddenBefore = _hiddenRecent.length;
      _hiddenRecent.removeWhere((pkg) => !currentPkgs.contains(pkg));
      if (_hiddenRecent.length != hiddenBefore) {
        unawaited(_saveHiddenRecent());
      }

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
  }

  Future<void> _launchApp(String packageName) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _launchLog.putIfAbsent(packageName, () => <int>[]);
    existing.insert(0, now);
    if (existing.length > _kMaxLaunchesPerApp) {
      _launchLog[packageName] = existing.sublist(0, _kMaxLaunchesPerApp);
    }
    final wasHidden = _hiddenRecent.remove(packageName);
    setState(() {});
    unawaited(_saveLaunchLog());
    if (wasHidden) unawaited(_saveHiddenRecent());
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

  Future<void> _uninstallOne(String packageName) async {
    await _uninstallApps([packageName]);
  }

  Future<void> _removeFromRecent(String packageName) async {
    final hadLog = _launchLog.containsKey(packageName);
    final alreadyHidden = _hiddenRecent.contains(packageName);
    if (!hadLog && alreadyHidden) return;
    setState(() {
      _launchLog.remove(packageName);
      _hiddenRecent.add(packageName);
    });
    if (hadLog) await _saveLaunchLog();
    if (!alreadyHidden) await _saveHiddenRecent();
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
    final controller = _pageController;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final lastLaunchMap = _deriveLastLaunchMap();
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: controller,
          onPageChanged: (i) {
            if (i == _kHotZonePageIndex || i == _kSearchPageIndex) {
              unawaited(_saveLastPage(i));
            }
            if (i == _kUnusedPageIndex) {
              setState(() => _unusedPageVisits++);
            }
          },
          children: [
            HotZonePage(
              apps: _apps,
              icons: _icons,
              launchLog: _launchLog,
              installedAt: _installedAt,
              protectedPackages: _protectedPackages,
              hiddenRecent: _hiddenRecent,
              notificationCounts: _notifCounts,
              loading: _loading,
              onLaunch: _launchApp,
              onUninstall: _uninstallOne,
              onToggleProtect: _toggleProtect,
              onRemoveFromRecent: _removeFromRecent,
              onRefresh: _refreshWithDiff,
            ),
            SearchPage(
              apps: _apps,
              icons: _icons,
              launchHistory: lastLaunchMap,
              installedAt: _installedAt,
              protectedPackages: _protectedPackages,
              notificationCounts: _notifCounts,
              loading: _loading,
              onLaunch: _launchApp,
              onUninstall: _uninstallOne,
              onToggleProtect: _toggleProtect,
              onRemoveFromRecent: _removeFromRecent,
            ),
            UnusedAppsPage(
              apps: _apps,
              icons: _icons,
              launchHistory: lastLaunchMap,
              protectedPackages: _protectedPackages,
              visitCounter: _unusedPageVisits,
              loading: _loading,
              onUninstallBatch: _uninstallApps,
              onToggleProtect: _toggleProtect,
              onLaunch: _launchApp,
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
