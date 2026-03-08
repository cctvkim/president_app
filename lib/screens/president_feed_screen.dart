import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_item.dart';
import '../services/ktv_api.dart';

class PresidentFeedScreen extends StatefulWidget {
  final KtvApi api;
  const PresidentFeedScreen({super.key, required this.api});

  @override
  State<PresidentFeedScreen> createState() => _PresidentFeedScreenState();
}

class _PresidentFeedScreenState extends State<PresidentFeedScreen> {
  static const _cacheKey = 'president_feed_cache_v1';
  static const _cacheTimeKey = 'president_feed_cache_time_v1';
  static const _cacheTtlSeconds = 300; // 5분

  List<ContentItem> _items = [];
  bool _loading = true;
  String? _error;

  // UI 필터(탭)
  int _tab = 0; // 0=전체, 1=영상, 2=카드뉴스

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  int _safeTs(DateTime dt) {
    final ms = dt.millisecondsSinceEpoch;
    // publishedAt이 비정상(0)이면 맨 뒤로 밀기
    return ms <= 0 ? -1 : ms;
  }

  void _sortNewestFirst(List<ContentItem> list) {
    list.sort((a, b) => _safeTs(b.publishedAt).compareTo(_safeTs(a.publishedAt)));
  }

  Future<void> _load({bool initial = false, bool forceNetwork = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!forceNetwork) {
        final cached = await _loadCacheIfFresh();
        if (cached != null) {
          final tmp = List<ContentItem>.from(cached);
          _sortNewestFirst(tmp); // ✅ 캐시도 최신순 정렬
          setState(() {
            _items = tmp;
            _loading = false;
          });
          return;
        }
      }

      final items = await widget.api.fetchPresidentFeed(rows: 50);

      final tmp = List<ContentItem>.from(items);
      _sortNewestFirst(tmp); // ✅ 네트워크 데이터 최신순 정렬

      setState(() {
        _items = tmp;
        _loading = false;
      });

      await _saveCache(tmp);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ContentItem> get _visibleItems {
    if (_tab == 1) return _items.where((e) => e.source == SourceType.video).toList();
    if (_tab == 2) return _items.where((e) => e.source == SourceType.cardNews).toList();
    return _items; // ✅ 전체는 이미 최신순 정렬된 _items 사용
  }

  Future<List<ContentItem>?> _loadCacheIfFresh() async {
    final sp = await SharedPreferences.getInstance();
    final ts = sp.getInt(_cacheTimeKey);
    final raw = sp.getString(_cacheKey);

    if (ts == null || raw == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - ts > _cacheTtlSeconds) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(List<ContentItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final raw = jsonEncode(items.map(_toJson).toList());
    await sp.setString(_cacheKey, raw);
    await sp.setInt(_cacheTimeKey, now);
  }

  Map<String, dynamic> _toJson(ContentItem it) => {
        'id': it.id,
        'source': it.source.name,
        'title': it.title,
        'description': it.description,
        'publishedAt': it.publishedAt.toIso8601String(),
        'thumbnailUrl': it.thumbnailUrl,
        'linkUrl': it.linkUrl,
        'viewCnt': it.viewCnt,
        'programName': it.programName,
        'categoryName': it.categoryName,
      };

  ContentItem _fromJson(Map<String, dynamic> m) => ContentItem(
        id: m['id'] as String,
        source: (m['source'] as String) == 'video' ? SourceType.video : SourceType.cardNews,
        title: m['title'] as String,
        description: m['description'] as String,
        publishedAt: DateTime.tryParse(m['publishedAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0),
        thumbnailUrl: m['thumbnailUrl'] as String,
        linkUrl: m['linkUrl'] as String,
        viewCnt: m['viewCnt'] as int?,
        programName: m['programName'] as String?,
        categoryName: m['categoryName'] as String?,
      );

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  String _dateLabel(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => _load(forceNetwork: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _TabChip(
                  label: '전체',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: '영상',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: '카드뉴스',
                  selected: _tab == 2,
                  onTap: () => setState(() => _tab = 2),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: () => _load(forceNetwork: true))
              : RefreshIndicator(
                  onRefresh: () => _load(forceNetwork: true),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _visibleItems.length,
                    itemBuilder: (context, i) {
                      final it = _visibleItems[i];
                      return _ContentCard(
                        item: it,
                        dateLabel: _dateLabel(it.publishedAt),
                        onOpen: () => _openUrl(it.linkUrl),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null,
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentItem item;
  final String dateLabel;
  final VoidCallback onOpen;

  const _ContentCard({
    required this.item,
    required this.dateLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final badge = item.source == SourceType.video ? '영상' : '카드뉴스';
    final sub = item.source == SourceType.video
        ? [
            if (item.programName != null && item.programName!.isNotEmpty) item.programName!,
            if (item.categoryName != null && item.categoryName!.isNotEmpty) item.categoryName!,
          ].join(' · ')
        : '';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: item.thumbnailUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Theme.of(context).colorScheme.secondaryContainer,
                          ),
                          child: Text(badge, style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        if (dateLabel.isNotEmpty) Text(dateLabel, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(sub, style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});

  bool _looksBad(String s) {
    final t = s.trim();
    return t.isEmpty || t == 'null' || t == 'NULL';
  }

  @override
  Widget build(BuildContext context) {
    var u = url.trim();
    if (u.startsWith('http://')) u = 'https://${u.substring(7)}';
    final q = u.indexOf('&ref=');
    if (q != -1) u = u.substring(0, q);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 92,
        height: 92,
        child: _looksBad(u)
            ? _placeholder(context, Icons.image_not_supported_outlined)
            : Image.network(
                u,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _placeholder(context, Icons.image_outlined);
                },
                errorBuilder: (_, __, ___) => _placeholder(context, Icons.broken_image_outlined),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(icon, color: Theme.of(context).colorScheme.outline),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        Text('에러', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(error),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      ],
    );
  }
}
