import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'korean_search.dart';

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

class _IndexedApp {
  final AppInfo app;
  final String nameLower;
  final String chosung;
  final String qwerty;
  final String roman;
  final String packageLower;

  _IndexedApp(this.app)
      : nameLower = app.name.toLowerCase(),
        chosung = extractChosung(app.name),
        qwerty = toQwerty(app.name),
        roman = romanize(app.name),
        packageLower = app.packageName.toLowerCase();
}

class _ScoredApp {
  final _IndexedApp app;
  final int score;
  _ScoredApp(this.app, this.score);
}

int _similarityScore(_IndexedApp a, String qLower, String qRoman, String qQwerty) {
  if (qRoman.isNotEmpty && a.roman.contains(qRoman)) {
    final pos = a.roman.indexOf(qRoman);
    final lenPenalty = (a.roman.length - qRoman.length).clamp(0, 1000);
    return 10000 - pos * 10 - lenPenalty;
  }
  if (qQwerty.isNotEmpty && a.qwerty.contains(qQwerty) && qQwerty != qRoman) {
    final pos = a.qwerty.indexOf(qQwerty);
    final lenPenalty = (a.qwerty.length - qQwerty.length).clamp(0, 1000);
    return 5000 - pos * 10 - lenPenalty;
  }
  final qForPkg = qRoman.isNotEmpty ? qRoman : qLower;
  if (qForPkg.length >= 2 && a.packageLower.contains(qForPkg)) {
    final pos = a.packageLower.indexOf(qForPkg);
    return 3000 - pos * 5;
  }
  final lcs = longestCommonSubstring(qRoman, a.roman);
  if (lcs >= 2) {
    return 1000 + lcs * 100;
  }
  final common = commonCharCount(qRoman, a.roman);
  if (common >= 1) {
    return common * 10;
  }
  return -1;
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  final TextEditingController _searchController = TextEditingController();
  List<_IndexedApp> _apps = [];
  List<_IndexedApp> _exactResults = [];
  List<_IndexedApp> _similarResults = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final indexed = apps.map((a) => _IndexedApp(a)).toList();
    setState(() {
      _apps = indexed;
      _exactResults = indexed;
      _similarResults = [];
      _loading = false;
    });
  }

  void _onSearchChanged() {
    final rawQuery = _searchController.text.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _exactResults = _apps;
        _similarResults = [];
      });
      return;
    }

    final qLower = rawQuery.toLowerCase();
    final qQwerty = toQwerty(rawQuery);
    final qRoman = romanize(rawQuery).toLowerCase();
    final qIsChosung = isAllChosung(rawQuery);

    final exact = <_IndexedApp>[];
    final scored = <_ScoredApp>[];

    for (final a in _apps) {
      final isExact = a.nameLower.contains(qLower) ||
          (qIsChosung && a.chosung.contains(rawQuery));
      if (isExact) {
        exact.add(a);
        continue;
      }
      final score = _similarityScore(a, qLower, qRoman, qQwerty);
      if (score > 0) {
        scored.add(_ScoredApp(a, score));
      }
    }

    scored.sort((x, y) {
      if (y.score != x.score) return y.score.compareTo(x.score);
      return x.app.nameLower.compareTo(y.app.nameLower);
    });

    setState(() {
      _exactResults = exact;
      _similarResults = scored.map((s) => s.app).toList();
    });
  }

  void _launchApp(AppInfo app) {
    InstalledApps.startApp(app.packageName);
  }

  SliverGridDelegate get _gridDelegate =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: '앱 검색 (초성/한영 혼용 가능)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exactResults.isEmpty && _similarResults.isEmpty) {
      return const Center(child: Text('검색 결과 없음'));
    }

    return CustomScrollView(
      slivers: [
        if (_exactResults.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = _exactResults[index];
                  return _AppTile(
                    app: a.app,
                    onTap: () => _launchApp(a.app),
                  );
                },
                childCount: _exactResults.length,
              ),
            ),
          ),
        if (_similarResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '유사 결과',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = _similarResults[index];
                  return _AppTile(
                    app: a.app,
                    onTap: () => _launchApp(a.app),
                  );
                },
                childCount: _similarResults.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final VoidCallback onTap;

  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Uint8List? icon = app.icon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon != null
              ? Image.memory(icon, width: 48, height: 48)
              : const Icon(Icons.android, size: 48),
          const SizedBox(height: 6),
          Text(
            app.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
