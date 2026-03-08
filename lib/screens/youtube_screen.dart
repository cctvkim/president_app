import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_service.dart';

class YoutubeFeedSource {
  final String name;
  final String channelId;

  // ✅ 제목에 반드시 포함되어야 하는 키워드들(하나라도 포함되면 통과)
  final List<String> titleMustContainAny;

  const YoutubeFeedSource({
    required this.name,
    required this.channelId,
    this.titleMustContainAny = const [],
  });
}


class YoutubeScreen extends StatefulWidget {
  final String apiKey;
  final List<YoutubeFeedSource> feeds;

  const YoutubeScreen({
    super.key,
    required this.apiKey,
    required this.feeds,
  });

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  String? _error;

  // 합쳐진 목록 (채널명 포함해서 표시하려고 래핑)
  final List<_VideoRow> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  List<YoutubeVideoLite> _applyTitleFilter(List<YoutubeVideoLite> list, YoutubeFeedSource src) {
    if (src.titleMustContainAny.isEmpty) return list;

    final keys = src.titleMustContainAny.map(_norm).toList();

    return list.where((v) {
      final t = _norm(v.title);
      return keys.any((k) => t.contains(k));
    }).toList();
  }

  String _norm(String s) => s.replaceAll(' ', '').toLowerCase();


  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _videos.clear();
    });

    try {
      if (widget.apiKey.trim().isEmpty) {
        throw Exception('YouTube API Key가 비어있음');
      }
      if (widget.feeds.isEmpty) {
        throw Exception('피드 채널 목록(feeds)이 비어있음');
      }

      // 채널별 최신 영상 가져와서 합치기
      final tasks = widget.feeds.map((src) async {
        final svc = YoutubeService(apiKey: widget.apiKey, channelId: src.channelId);
        final list = await svc.fetchLatestVideos(max: 15); // 채널당 15개 정도

        // ✅ 제목 필터 적용(키워드 없으면 그대로 통과)
        final filtered = _applyTitleFilter(list, src);

        return filtered.map((v) => _VideoRow(channelName: src.name, v: v)).toList();
      }).toList();


      final results = await Future.wait(tasks);
      final merged = results.expand((e) => e).toList();

      // 최신순 정렬
      merged.sort((a, b) => b.v.publishedAt.compareTo(a.v.publishedAt));

      setState(() {
        _videos.addAll(merged);
        _loading = false;
      });
    } catch (e) {
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

  String _date(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ keepAlive 필수
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('에러', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _videos.length,
                    itemBuilder: (context, i) {
                      final row = _videos[i];
                      final v = row.v;

                      return Card(
                        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _open(v.watchUrl), // ✅ 카드 탭하면 유튜브 이동
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 112,
                                    height: 70,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: v.thumbnailUrl.isEmpty
                                        ? const Icon(Icons.image_not_supported_outlined)
                                        : Image.network(
                                            v.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 채널명 배지
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: Theme.of(context).colorScheme.secondaryContainer,
                                        ),
                                        child: Text(
                                          row.channelName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        v.title.isEmpty ? '(제목 없음)' : v.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        children: [
                                          if (_date(v.publishedAt).isNotEmpty)
                                            _miniMeta(Icons.event, _date(v.publishedAt), context),
                                          _miniMeta(Icons.visibility_outlined, _fmt(v.viewCount), context),
                                          _miniMeta(Icons.thumb_up_alt_outlined, _fmt(v.likeCount), context),
                                          _miniMeta(Icons.chat_bubble_outline, _fmt(v.commentCount), context),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _miniMeta(IconData icon, String text, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VideoRow {
  final String channelName;
  final YoutubeVideoLite v;
  _VideoRow({required this.channelName, required this.v});
}
