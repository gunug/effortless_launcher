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
  final Map<String, int> installedAt;
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
    required this.installedAt,
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
          title: const Text('자주 사용하는 앱'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('이 런처에서 실행한 앱들을 평가하여 상위 28개를 자동 정렬합니다.'),
                const SizedBox(height: 16),
                Text('정렬 규칙', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• 최근 7일 이내 설치된 앱은 NEW 배지와 함께 최상위에 먼저 표시됩니다'),
                const Text('• 자주 사용할수록 앞에 표시됩니다'),
                const Text('• 최근에 사용할수록 앞에 표시됩니다'),
                const Text('• 사용하지 않을수록 뒤로 밀려납니다'),
                const SizedBox(height: 16),
                Text('알아두세요', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• 7일이 지나면 NEW 배지는 사라지고 일반 정렬에 편입됩니다'),
                const Text('• 이 기간 동안 자주 쓰던 앱은 이후에도 상위에 유지될 수 있습니다'),
                const Text('• 이 런처를 통해 실행한 기록만 집계됩니다 (앱당 최근 50회까지)'),
                const Text('• 순위는 페이지 재방문 시 갱신됩니다'),
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text('(같은 페이지에 머무는 동안은 순서 고정)'),
                ),
                const Text("• '표시 제거' 기능을 사용하여 즉시 제외(재 집계) 가능합니다"),
                const Text('• 🔒 배지: 보호된 앱. 앱 관리 페이지에서 삭제 불가'),
                const Text('• 길게 눌러: 삭제 / 표시 제거 / 보호'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
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
                  '자주 사용하는 앱',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                tooltip: '도움말',
                visualDensity: VisualDensity.compact,
                onPressed: _showHelp,
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
