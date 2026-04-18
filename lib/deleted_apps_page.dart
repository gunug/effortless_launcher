import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

class DeletedAppsPage extends StatefulWidget {
  final List<DeletedApp> deletedApps;
  final Map<String, Uint8List> icons;
  final Future<void> Function(List<String> packageNames) onRemoveRecords;

  const DeletedAppsPage({
    super.key,
    required this.deletedApps,
    required this.icons,
    required this.onRemoveRecords,
  });

  @override
  State<DeletedAppsPage> createState() => _DeletedAppsPageState();
}

class _DeletedAppsPageState extends State<DeletedAppsPage> {
  final Set<String> _selected = {};

  String _formatConfirmed(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '삭제 확인 시각: ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openPlayStore(String packageName) async {
    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri =
        Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _removeSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 지우기'),
        content: Text('${_selected.length}개 기록을 지웁니다. (실제 앱 재설치와는 무관)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final pkgs = _selected.toList();
    setState(() => _selected.clear());
    await widget.onRemoveRecords(pkgs);
  }

  @override
  Widget build(BuildContext context) {
    final list = [...widget.deletedApps]
      ..sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt));

    if (list.isEmpty) {
      return const Center(child: Text('삭제 기록 없음'));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '삭제된 앱  ${list.length}개',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '선택 ${_selected.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _removeSelected,
                icon: const Icon(Icons.clear_all),
                label: const Text('기록 지우기'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final d = list[index];
              final icon = widget.icons[d.packageName];
              final checked = _selected.contains(d.packageName);
              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(d.packageName);
                          } else {
                            _selected.remove(d.packageName);
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
                  d.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _formatConfirmed(d.confirmedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.shop, size: 18),
                  label: const Text('재설치'),
                  onPressed: () => _openPlayStore(d.packageName),
                ),
                onTap: () {
                  setState(() {
                    if (checked) {
                      _selected.remove(d.packageName);
                    } else {
                      _selected.add(d.packageName);
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
