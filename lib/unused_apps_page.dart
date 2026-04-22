import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';

class UnusedAppsPage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, int> launchHistory;
  final Set<String> protectedPackages;
  final int visitCounter;
  final bool loading;
  final Future<void> Function(List<String> packageNames) onUninstallBatch;
  final Future<void> Function(String packageName) onToggleProtect;
  final Future<void> Function(String packageName) onLaunch;

  const UnusedAppsPage({
    super.key,
    required this.apps,
    required this.icons,
    required this.launchHistory,
    required this.protectedPackages,
    required this.visitCounter,
    required this.loading,
    required this.onUninstallBatch,
    required this.onToggleProtect,
    required this.onLaunch,
  });

  @override
  State<UnusedAppsPage> createState() => _UnusedAppsPageState();
}

class _UnusedAppsPageState extends State<UnusedAppsPage> {
  final Set<String> _selected = {};
  late Set<String> _committedProtected;

  @override
  void initState() {
    super.initState();
    _committedProtected = Set.of(widget.protectedPackages);
  }

  @override
  void didUpdateWidget(covariant UnusedAppsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visitCounter != widget.visitCounter) {
      setState(() {
        _committedProtected = Set.of(widget.protectedPackages);
      });
    }
    final stale = _selected
        .where((p) => widget.protectedPackages.contains(p))
        .toList();
    if (stale.isNotEmpty) {
      setState(() {
        for (final p in stale) {
          _selected.remove(p);
        }
      });
    }
  }

  int _sortCompare(IndexedApp a, IndexedApp b) {
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
  }

  ({List<IndexedApp> normal, List<IndexedApp> protected}) _partition() {
    final normal = <IndexedApp>[];
    final protected = <IndexedApp>[];
    for (final a in widget.apps) {
      if (a.isSystemApp) continue;
      if (_committedProtected.contains(a.packageName)) {
        protected.add(a);
      } else {
        normal.add(a);
      }
    }
    normal.sort(_sortCompare);
    protected.sort(_sortCompare);
    return (normal: normal, protected: protected);
  }

  String _formatLastUsed(int? ts) {
    if (ts == null) return 'Never used';
    final now = DateTime.now();
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final days = now.difference(d).inDays;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'Last used: $dateStr ($days days ago)';
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected'),
        content: Text('Deleting ${_selected.length} apps one by one.\n'
            'Each app will show a system prompt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
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

  Widget _buildRow(IndexedApp a) {
    final isProtectedLive = widget.protectedPackages.contains(a.packageName);
    final ts = widget.launchHistory[a.packageName];
    final icon = widget.icons[a.packageName];
    final checked = _selected.contains(a.packageName);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: isProtectedLive ? false : checked,
            onChanged: isProtectedLive
                ? null
                : (v) {
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isProtectedLive ? Icons.lock : Icons.lock_open_outlined,
              color: isProtectedLive
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: isProtectedLive ? 'Unprotect' : 'Protect',
            onPressed: () => widget.onToggleProtect(a.packageName),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isProtectedLive ? "Protected — can't delete" : 'Delete',
            onPressed:
                isProtectedLive ? null : () => _deleteOne(a.packageName),
          ),
        ],
      ),
      onTap: () => widget.onLaunch(a.packageName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final parts = _partition();
    final total = parts.normal.length + parts.protected.length;
    if (total == 0) {
      return const Center(child: Text('No apps'));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'App Manager  $total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'Selected: ${_selected.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _deleteSelected,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Delete selected'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: parts.normal.length +
                (parts.protected.isEmpty ? 0 : 1 + parts.protected.length),
            itemBuilder: (context, index) {
              if (index < parts.normal.length) {
                return _buildRow(parts.normal[index]);
              }
              final afterNormal = index - parts.normal.length;
              if (afterNormal == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Protected  ${parts.protected.length}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Divider()),
                    ],
                  ),
                );
              }
              return _buildRow(parts.protected[afterNormal - 1]);
            },
          ),
        ),
      ],
    );
  }
}
