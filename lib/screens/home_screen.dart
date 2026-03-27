// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_item.dart';
import '../services/ktv_api.dart';
import '../services/korea_kr_rss.dart';
import '../widgets/home_youtube_card.dart';

class HomeScreen extends StatefulWidget {
  final KtvApi api;
  final String youtubeServerBaseUrl;
  final String youtubeChannelId;

  const HomeScreen({
    super.key,
    required this.api,
    required this.youtubeServerBaseUrl,
    required this.youtubeChannelId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  List<ContentItem> _videos = [];
  List<ContentItem> _cards = [];
  List<ContentItem> _rss = [];

  final KoreaKrRssService _rssSvc = KoreaKrRssService.defaultPresident();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final feed = await widget.api.fetchPresidentFeed(rows: 30);

      _videos = feed.where((e) => e.source == SourceType.video).take(2).toList();
      _cards = feed.where((e) => e.source == SourceType.cardNews).take(2).toList();

      _rss = await _rssSvc.fetch(limit: 2);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorBlock(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      const _TodayPresidentBlock(),
                      const SizedBox(height: 14),

                      // 1행: KTV / 카드뉴스
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MiniFeedCard(
                              title: 'KTV 영상',
                              icon: Icons.play_circle_outline_rounded,
                              headerColor: const Color(0xFF7C4DFF),
                              items: _videos,
                              onTapItem: (it) => _open(it.linkUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MiniFeedCard(
                              title: '카드뉴스',
                              icon: Icons.article_outlined,
                              headerColor: const Color(0xFFFF7043),
                              items: _cards,
                              onTapItem: (it) => _open(it.linkUrl),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 2행: RSS / YouTube
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MiniFeedCard(
                              title: 'RSS',
                              icon: Icons.feed_outlined,
                              headerColor: const Color(0xFF26A69A),
                              items: _rss,
                              onTapItem: (it) => _open(it.linkUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 270,
                              child: HomeYoutubeCard(
                                baseUrl: widget.youtubeServerBaseUrl,
                                channelId: widget.youtubeChannelId,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '안내',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '본 앱은 대한민국 정부 또는 대통령실과 제휴하거나 공식적으로 운영되는 앱이 아닙니다.\n'
                                '공개된 공식 웹사이트 및 공개 API 자료를 기반으로 제공되는 비공식 정보 제공 앱입니다.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/* ------------------------- */
/*   TODAY PRESIDENT BLOCK   */
/* ------------------------- */

class _TodayPresidentBlock extends StatelessWidget {
  const _TodayPresidentBlock();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.today_rounded,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  const Text(
                    '오늘의 대통령',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------- */
/*        MINI FEED CARD     */
/* ------------------------- */

class _MiniFeedCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color headerColor;
  final List<ContentItem> items;
  final void Function(ContentItem it) onTapItem;

  const _MiniFeedCard({
    required this.title,
    required this.icon,
    required this.headerColor,
    required this.items,
    required this.onTapItem,
  });

  String _hostOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return '';
    return u.host;
  }

  String _date(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, icon: icon, color: headerColor),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Icon(
                    Icons.inbox_outlined,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            else
              for (final it in items) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onTapItem(it),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _date(it.publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (_) {
                            final host = _hostOf(it.linkUrl);
                            if (host.isEmpty) return const SizedBox.shrink();
                            return Text(
                              '출처: $host',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (it != items.last)
                  Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.25),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.22),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- */
/*          ERROR BLOCK      */
/* ------------------------- */

class _ErrorBlock extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorBlock({
    required this.error,
    required this.onRetry,
  });

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
