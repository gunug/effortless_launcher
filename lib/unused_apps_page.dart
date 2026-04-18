import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';

class UnusedAppsPage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, int> launchHistory;
  final bool loading;
  final Future<void> Function(List<String> packageNames) onUninstallBatch;

  const UnusedAppsPage({
    super.key,
    required this.apps,
    required this.icons,
    required this.launchHistory,
    required this.loading,
    required this.onUninstallBatch,
  });

  @override
  State<UnusedAppsPage> createState() => _UnusedAppsPageState();
}

class _UnusedAppsPageState extends State<UnusedAppsPage> {
  final Set<String> _selected = {};

  List<IndexedApp> _buildList() {
    final list = widget.apps.where((a) => !a.isSystemApp).toList();
    list.sort((a, b) {
      final tsA = widget.launchHistory[a.packageName];
      final tsB = widget.launchHistory[b.packageName];
      final aNever = tsA == null;
      final bNever = tsB == null;
      if (aNever && bNever) {
        return a.nameLower.compareTo(b.nameLower);
      }
      if (aNever) return -1;
      if (bNever) return 1;
      return tsA.compareTo(tsB);
    });
    return list;
  }

  String _formatLastUsed(int? ts) {
    if (ts == null) return '사용 이력 없음';
    final now = DateTime.now();
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final days = now.difference(d).inDays;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '마지막 사용: $dateStr ($days일 전)';
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택한 앱 삭제'),
        content: Text('${_selected.length}개 앱을 순차적으로 삭제합니다.\n'
            '각 앱마다 시스템 확인 창이 표시됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('진행'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final pkgs = _selected.toList();
    setState(() => _selected.clear());
    await widget.onUninstallBatch(pkgs);
  }

  Future<void> _deleteOne(String packageName) async {
    await widget.onUninstallBatch([packageName]);
    setState(() => _selected.remove(packageName));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final apps = _buildList();
    if (apps.isEmpty) {
      return const Center(child: Text('정리할 앱 없음'));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '미사용 앱  ${apps.length}개',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '선택 ${_selected.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('선택 삭제'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final a = apps[index];
              final ts = widget.launchHistory[a.packageName];
              final icon = widget.icons[a.packageName];
              final checked = _selected.contains(a.packageName);
              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(a.packageName);
                          } else {
                            _selected.remove(a.packageName);
                          }
                        });
                      },
                    ),
                    icon != null
                        ? Image.memory(icon,
                            width: 40, height: 40, gaplessPlayback: true)
                        : const Icon(Icons.android, size: 40),
                  ],
                ),
                title: Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatLastUsed(ts),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '삭제',
                  onPressed: () => _deleteOne(a.packageName),
                ),
                onTap: () {
                  setState(() {
                    if (checked) {
                      _selected.remove(a.packageName);
                    } else {
                      _selected.add(a.packageName);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
