import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_context_menu.dart';
import 'donation_dialog.dart';
import 'models.dart';
import 'search_page.dart';

const int _kHotZoneLimit = 28;
const double _kTauMs = 14 * 24 * 60 * 60 * 1000.0;

class HotZonePage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, List<int>> launchLog;
  final Map<String, int> installedAt;
  final Set<String> protectedPackages;
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
    required this.installedAt,
    required this.protectedPackages,
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
    _committed = _compute();
  }

  List<IndexedApp> _compute() {
    if (widget.apps.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final newCutoff = now - kNewAppWindowMs;

    final newApps = <IndexedApp>[];
    final scored = <_Scored>[];
    for (final a in widget.apps) {
      final installTs = widget.installedAt[a.packageName];
      final isNew = installTs != null && installTs > 0 && installTs >= newCutoff;
      if (isNew) {
        newApps.add(a);
        continue;
      }
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

    newApps.sort((x, y) {
      final tsX = widget.installedAt[x.packageName] ?? 0;
      final tsY = widget.installedAt[y.packageName] ?? 0;
      final cmp = tsY.compareTo(tsX);
      if (cmp != 0) return cmp;
      return x.nameLower.compareTo(y.nameLower);
    });
    scored.sort((x, y) {
      final cmp = y.score.compareTo(x.score);
      if (cmp != 0) return cmp;
      return x.lastLaunch.compareTo(y.lastLaunch);
    });

    final result = <IndexedApp>[];
    for (final a in newApps) {
      if (result.length >= _kHotZoneLimit) break;
      result.add(a);
    }
    for (final s in scored) {
      if (result.length >= _kHotZoneLimit) break;
      result.add(s.app);
    }
    return List<IndexedApp>.unmodifiable(result);
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final titleSmall = Theme.of(ctx).textTheme.titleSmall;
        return AlertDialog(
          title: const Text('Frequently Used'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Auto-ranks the top 28 apps launched from this launcher.'),
                const SizedBox(height: 16),
                Text('Ranking rules', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• Apps installed in the last 7 days appear first with a NEW badge'),
                const Text('• The more often you use an app, the higher it ranks'),
                const Text('• The more recently you use an app, the higher it ranks'),
                const Text('• Unused apps move down over time'),
                const SizedBox(height: 16),
                Text('Good to know', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• After 7 days the NEW badge disappears and normal ranking applies'),
                const Text('• Apps used often during this period may stay high'),
                const Text('• Only launches from this launcher are counted (up to 50 per app)'),
                const Text('• Ranking updates on every change (launch, install, delete)'),
                const Text("• Use 'Hide' to remove an app and restart its tracking"),
                const Text("• 🔒 badge: Protected. Can't delete in App Manager"),
                const Text('• Long press: Delete / Hide / Protect'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Frequently Used',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                tooltip: 'Help',
                visualDensity: VisualDensity.compact,
                onPressed: _showHelp,
              ),
              IconButton(
                icon: const Icon(Icons.attach_money, size: 20),
                tooltip: 'Support',
                visualDensity: VisualDensity.compact,
                onPressed: () => showDonationDialog(context),
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
                      'Apps you use most will appear here',
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
                      isNew: isNewApp(widget.installedAt, a.packageName),
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
