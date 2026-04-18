import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'korean_search.dart';
import 'models.dart';

const int _kMaxResults = 100;
const int _kMaxRecent = 16;

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

class SearchPage extends StatefulWidget {
  final List<IndexedApp> apps;
  final Map<String, Uint8List> icons;
  final Map<String, int> launchHistory;
  final bool loading;
  final Future<void> Function(String packageName) onLaunch;

  const SearchPage({
    super.key,
    required this.apps,
    required this.icons,
    required this.launchHistory,
    required this.loading,
    required this.onLaunch,
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
    );
  }

  Widget _buildResults() {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exactResults.isEmpty && _similarResults.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;
      return Center(
        child: Text(isSearching ? '검색 결과 없음' : '앱을 실행하면 최근 사용에 추가됩니다'),
      );
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
                  return AppGridTile(
                    name: a.name,
                    icon: widget.icons[a.packageName],
                    onTap: () => widget.onLaunch(a.packageName),
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
                  return AppGridTile(
                    name: a.name,
                    icon: widget.icons[a.packageName],
                    onTap: () => widget.onLaunch(a.packageName),
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

class AppGridTile extends StatelessWidget {
  final String name;
  final Uint8List? icon;
  final VoidCallback onTap;
  final double opacity;

  const AppGridTile({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = icon;
    final tile = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          bytes != null
              ? Image.memory(bytes, width: 48, height: 48, gaplessPlayback: true)
              : const Icon(Icons.android, size: 48),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
    if (opacity >= 1.0) return tile;
    return Opacity(opacity: opacity, child: tile);
  }
}
