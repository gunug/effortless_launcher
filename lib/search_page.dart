import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_context_menu.dart';
import 'donation_dialog.dart';
import 'korean_search.dart';
import 'models.dart';

const int _kMaxResults = 100;
const int _kMaxRecent = 24;

class _ScoredApp {
  final IndexedApp app;
  final int score;
  _ScoredApp(this.app, this.score);
}

int _similarityScore(IndexedApp a, String qLower, String qRoman, String qQwerty) {
  if (qRoman.isNotEmpty && a.roman.contains(qRoman)) {
    final pos = a.roman.indexOf(qRoman);
    final lenPenalty = (a.roman.length - qRoman.length).clamp(0, 1000);
    final bonus = wordBoundaryBonusAt(a.roman, pos);
    return 10000 - pos * 10 - lenPenalty + bonus;
  }
  if (qQwerty.isNotEmpty && a.qwerty.contains(qQwerty) && qQwerty != qRoman) {
    final pos = a.qwerty.indexOf(qQwerty);
    final lenPenalty = (a.qwerty.length - qQwerty.length).clamp(0, 1000);
    final bonus = wordBoundaryBonusAt(a.qwerty, pos);
    return 5000 - pos * 10 - lenPenalty + bonus;
  }
  if (qRoman.length >= 3) {
    final maxEdit = qRoman.length <= 4
        ? 1
        : qRoman.length <= 6
            ? 2
            : (qRoman.length * 0.3).floor();
    final edit = minEditDistanceWindow(qRoman, a.roman);
    if (edit > 0 && edit <= maxEdit) {
      return 4000 - edit * 500;
    }
  }
  final qForPkg = qRoman.isNotEmpty ? qRoman : qLower;
  if (qForPkg.length >= 2 && a.packageLower.contains(qForPkg)) {
    final pos = a.packageLower.indexOf(qForPkg);
    return 3000 - pos * 5;
  }
  if (qLower.length >= 2 && a.initials.isNotEmpty && a.initials.contains(qLower)) {
    final pos = a.initials.indexOf(qLower);
    return 2500 - pos * 50;
  }
  final lcs = longestCommonSubstring(qRoman, a.roman);
  if (lcs >= 2) {
    return 1000 + lcs * 100;
  }
  if (qRoman.length >= 3 && isSubsequence(qRoman, a.roman)) {
    final spread = subsequenceSpread(qRoman, a.roman);
    final tightness = (200 - spread).clamp(0, 200);
    return 500 + tightness;
  }
  final common = commonCharCount(qRoman, a.roman);
  if (common >= 1) {
    return common * 10;
  }
  return -1;
}

const int kNewAppWindowMs = 7 * 24 * 60 * 60 * 1000;

bool isNewApp(Map<String, int> installedAt, String packageName) {
  final ts = installedAt[packageName];
  if (ts == null || ts == 0) return false;
  return DateTime.now().millisecondsSinceEpoch - ts < kNewAppWindowMs;
}

class SearchPage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, int> launchHistory;
  final Map<String, int> installedAt;
  final Set<String> protectedPackages;
  final Map<String, int> notificationCounts;
  final bool loading;
  final Future<void> Function(String packageName) onLaunch;
  final Future<void> Function(String packageName) onUninstall;
  final Future<void> Function(String packageName) onToggleProtect;
  final Future<void> Function(String packageName) onRemoveFromRecent;

  const SearchPage({
    super.key,
    required this.apps,
    required this.icons,
    required this.launchHistory,
    required this.installedAt,
    required this.protectedPackages,
    required this.notificationCounts,
    required this.loading,
    required this.onLaunch,
    required this.onUninstall,
    required this.onToggleProtect,
    required this.onRemoveFromRecent,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<IndexedApp> _exactResults = [];
  List<IndexedApp> _similarResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _exactResults = _recentApps();
  }

  @override
  void didUpdateWidget(covariant SearchPage old) {
    super.didUpdateWidget(old);
    if (old.apps != widget.apps || old.launchHistory != widget.launchHistory) {
      _onSearchChanged();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<IndexedApp> _recentApps() {
    if (widget.launchHistory.isEmpty) return const [];
    final withTs = <MapEntry<int, IndexedApp>>[];
    for (final a in widget.apps) {
      final ts = widget.launchHistory[a.packageName];
      if (ts != null) withTs.add(MapEntry(ts, a));
    }
    withTs.sort((x, y) => y.key.compareTo(x.key));
    final take = withTs.length < _kMaxRecent ? withTs.length : _kMaxRecent;
    return withTs.take(take).map((e) => e.value).toList();
  }

  void _onSearchChanged() {
    final rawQuery = _searchController.text.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _exactResults = _recentApps();
        _similarResults = [];
      });
      return;
    }

    final qLower = rawQuery.toLowerCase();
    final qQwerty = toQwerty(rawQuery);
    final qRoman = romanize(rawQuery).toLowerCase();
    final qIsChosung = isAllChosung(rawQuery);

    final exact = <IndexedApp>[];
    final scored = <_ScoredApp>[];

    for (final a in widget.apps) {
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

    final exactCapped =
        exact.length > _kMaxResults ? exact.sublist(0, _kMaxResults) : exact;
    final remaining = _kMaxResults - exactCapped.length;
    final similarCapped = remaining <= 0
        ? <IndexedApp>[]
        : scored.take(remaining).map((s) => s.app).toList();

    setState(() {
      _exactResults = exactCapped;
      _similarResults = similarCapped;
    });
  }

  SliverGridDelegate get _gridDelegate =>
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
      );

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

  void _showRecentHelp() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final titleSmall = Theme.of(ctx).textTheme.titleSmall;
        return AlertDialog(
          title: const Text('Recently Used'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Shows up to 24 apps you recently launched from this launcher.'),
                const SizedBox(height: 16),
                Text('Order', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• Most recently used apps appear first'),
                const SizedBox(height: 16),
                Text('Good to know', style: titleSmall),
                const SizedBox(height: 6),
                const Text('• Only launches from this launcher are counted'),
                const Text('• Type in the search box to find any app'),
                const Text("• Use 'Hide' to remove an app from this list"),
                const Text("• 🔒 badge: Protected. Can't delete in App Manager"),
                const Text('• NEW badge: Installed in the last 7 days'),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search apps',
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
    );
  }

  Widget _buildResults() {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exactResults.isEmpty && _similarResults.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Text(isSearching ? 'No results' : 'Launch an app to see recents'),
      );
    }

    final isRecentMode = _searchController.text.trim().isEmpty;
    return CustomScrollView(
      slivers: [
        if (isRecentMode && _exactResults.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recently Used',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, size: 20),
                    tooltip: 'Help',
                    visualDensity: VisualDensity.compact,
                    onPressed: _showRecentHelp,
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
          ),
        if (_exactResults.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: _gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final a = _exactResults[index];
                  return AppGridTile(
                    name: a.name,
                    icon: widget.icons[a.packageName],
                    isProtected:
                        widget.protectedPackages.contains(a.packageName),
                    isNew: isNewApp(widget.installedAt, a.packageName),
                    notificationCount:
                        widget.notificationCounts[a.packageName] ?? 0,
                    onTap: () => widget.onLaunch(a.packageName),
                    onLongPress: (pos) => _showContextMenu(pos, a),
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
                    'Similar',
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
                  return AppGridTile(
                    name: a.name,
                    icon: widget.icons[a.packageName],
                    isProtected:
                        widget.protectedPackages.contains(a.packageName),
                    isNew: isNewApp(widget.installedAt, a.packageName),
                    notificationCount:
                        widget.notificationCounts[a.packageName] ?? 0,
                    onTap: () => widget.onLaunch(a.packageName),
                    onLongPress: (pos) => _showContextMenu(pos, a),
                    opacity: 0.8,
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

class AppGridTile extends StatefulWidget {
  final String name;
  final Uint8List? icon;
  final bool isProtected;
  final bool isNew;
  final int notificationCount;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;
  final double opacity;

  const AppGridTile({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
    this.isProtected = false,
    this.isNew = false,
    this.notificationCount = 0,
    this.onLongPress,
    this.opacity = 1.0,
  });

  @override
  State<AppGridTile> createState() => _AppGridTileState();
}

class _AppGridTileState extends State<AppGridTile> {
  Offset _pressPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final bytes = widget.icon;
    final iconBox = SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: bytes != null
                ? Image.memory(bytes, width: 48, height: 48, gaplessPlayback: true)
                : const Icon(Icons.android, size: 48),
          ),
          if (widget.isProtected)
            Positioned(
              top: -2,
              left: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 0.8),
                ),
                child: const Icon(Icons.lock, size: 10, color: Colors.white),
              ),
            ),
          if (widget.isNew)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 0.8),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          if (widget.notificationCount > 0)
            Positioned(
              bottom: -4,
              right: -4,
              child: _NotificationBadge(count: widget.notificationCount),
            ),
        ],
      ),
    );

    final tile = InkWell(
      onTap: widget.onTap,
      onTapDown: (d) => _pressPosition = d.globalPosition,
      onLongPress: widget.onLongPress == null
          ? null
          : () => widget.onLongPress!(_pressPosition),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconBox,
          const SizedBox(height: 6),
          Text(
            widget.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
    if (widget.opacity >= 1.0) return tile;
    return Opacity(opacity: widget.opacity, child: tile);
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;
  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final isWide = label.length >= 2;
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 4 : 0,
        vertical: 0,
      ),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.0),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}
