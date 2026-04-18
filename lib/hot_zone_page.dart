import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_context_menu.dart';
import 'models.dart';
import 'search_page.dart';

const int _kHotZoneLimit = 28;
const double _kTauMs = 14 * 24 * 60 * 60 * 1000.0;

class HotZonePage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, List<int>> launchLog;
  final Set<String> protectedPackages;
  final int visitCounter;
  final bool loading;
  final Future<void> Function(String packageName) onLaunch;
  final Future<void> Function(String packageName) onUninstall;
  final Future<void> Function(String packageName) onToggleProtect;
  final Future<void> Function(String packageName) onRemoveFromRecent;

  const HotZonePage({
    super.key,
    required this.apps,
    required this.icons,
    required this.launchLog,
    required this.protectedPackages,
    required this.visitCounter,
    required this.loading,
    required this.onLaunch,
    required this.onUninstall,
    required this.onToggleProtect,
    required this.onRemoveFromRecent,
  });

  @override
  State<HotZonePage> createState() => _HotZonePageState();
}

class _HotZonePageState extends State<HotZonePage> {
  List<IndexedApp> _committed = const [];

  @override
  void initState() {
    super.initState();
    _committed = _compute();
  }

  @override
  void didUpdateWidget(covariant HotZonePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitCounter != widget.visitCounter) {
      setState(() => _committed = _compute());
    }
  }

  List<IndexedApp> _compute() {
    if (widget.apps.isEmpty || widget.launchLog.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final scored = <_Scored>[];
    for (final a in widget.apps) {
      final log = widget.launchLog[a.packageName];
      if (log == null || log.isEmpty) continue;
      var sum = 0.0;
      for (final ts in log) {
        final age = (now - ts).toDouble();
        if (age < 0) continue;
        sum += math.exp(-age / _kTauMs);
      }
      if (sum > 0) scored.add(_Scored(a, sum, log.first));
    }
    scored.sort((x, y) {
      final cmp = y.score.compareTo(x.score);
      if (cmp != 0) return cmp;
      return x.lastLaunch.compareTo(y.lastLaunch);
    });
    return scored
        .take(_kHotZoneLimit)
        .map((e) => e.app)
        .toList(growable: false);
  }

  Future<void> _showContextMenu(Offset position, IndexedApp app) {
    return showAppContextMenu(
      context: context,
      position: position,
      packageName: app.packageName,
      isProtected: widget.protectedPackages.contains(app.packageName),
      onDelete: widget.onUninstall,
      onRemoveFromRecent: widget.onRemoveFromRecent,
      onToggleProtect: widget.onToggleProtect,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, size: 20),
              const SizedBox(width: 6),
              Text(
                '자주 사용하는 앱',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: _committed.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '앱을 실행하면 자주 사용하는 앱이 여기에 표시됩니다',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _committed.length,
                  itemBuilder: (context, index) {
                    final a = _committed[index];
                    return AppGridTile(
                      name: a.name,
                      icon: widget.icons[a.packageName],
                      isProtected:
                          widget.protectedPackages.contains(a.packageName),
                      onTap: () => widget.onLaunch(a.packageName),
                      onLongPress: (pos) => _showContextMenu(pos, a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Scored {
  final IndexedApp app;
  final double score;
  final int lastLaunch;
  _Scored(this.app, this.score, this.lastLaunch);
}
