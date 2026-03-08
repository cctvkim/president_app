import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_service.dart';

class PresidentSnsScreen extends StatelessWidget {
  final String youtubeApiKey;

  const PresidentSnsScreen({
    super.key,
    required this.youtubeApiKey,
  });

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final items = <_SnsItem>[
      _SnsItem(
        name: 'Facebook',
        subtitle: '이재명 대통령',
        icon: Icons.facebook,
        color: const Color(0xFF1877F2),
        url: 'https://www.facebook.com/jaemyunglee',
      ),
      _SnsItem(
        name: 'X',
        subtitle: '이재명 대통령',
        icon: Icons.close,
        color: Colors.black,
        url: 'https://x.com/Jaemyung_Lee',
      ),
      _SnsItem(
        name: 'Instagram',
        subtitle: '이재명 대통령',
        icon: Icons.camera_alt,
        color: const Color(0xFFE4405F),
        url: 'https://www.instagram.com/2_jaemyung/',
      ),
      _SnsItem(
        name: 'YouTube',
        subtitle: '이재명 채널',
        icon: Icons.play_circle_fill,
        color: const Color(0xFFFF0000),
        url: 'https://www.youtube.com/@%EC%9D%B4%EC%9E%AC%EB%AA%85tv',
      ),
      _SnsItem(
        name: 'TikTok',
        subtitle: '@jaemyung_lee',
        icon: Icons.music_note,
        color: const Color(0xFF111111),
        url: 'https://www.tiktok.com/@jaemyung_lee',
      ),
      _SnsItem(
        name: '짤짤짤',
        subtitle: '@KimJason-l3b',
        icon: Icons.video_library,
        color: const Color(0xFF6A1B9A),
        url: 'https://www.youtube.com/@KimJason-l3b',
        routeBuilder: () => JjalJjalJjalFeedScreen(
          apiKey: youtubeApiKey,
          channelId: 'UCB5BTzhRyNjBcGdqsAyXJTw',
          channelUrl: 'https://www.youtube.com/@KimJason-l3b',
          title: '짤짤짤',
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SNS'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (context, i) {
          final it = items[i];
          return _SnsCard(
            item: it,
            onTap: () {
              if (it.routeBuilder != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => it.routeBuilder!()),
                );
              } else {
                _open(it.url);
              }
            },
          );
        },
      ),
    );
  }
}

class JjalJjalJjalFeedScreen extends StatefulWidget {
  final String apiKey;
  final String channelId;
  final String channelUrl;
  final String title;

  const JjalJjalJjalFeedScreen({
    super.key,
    required this.apiKey,
    required this.channelId,
    required this.channelUrl,
    required this.title,
  });

  @override
  State<JjalJjalJjalFeedScreen> createState() => _JjalJjalJjalFeedScreenState();
}

class _JjalJjalJjalFeedScreenState extends State<JjalJjalJjalFeedScreen> {
  bool _loading = true;
  String? _error;
  final List<YoutubeVideoLite> _videos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _norm(String s) => s.replaceAll(' ', '').toLowerCase();

  bool _looksLikeShort(YoutubeVideoLite v) {
    final t = _norm(v.title);
    return t.contains('#shorts') || t.contains('shorts') || t.contains('쇼츠');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _videos.clear();
    });

    try {
      final svc = YoutubeService(
        apiKey: widget.apiKey,
        channelId: widget.channelId,
      );

      final list = await svc.fetchLatestVideos(max: 20);
      final shortsOnly = list.where(_looksLikeShort).toList();

      if (!mounted) return;
      setState(() {
        _videos.addAll(shortsOnly.isNotEmpty ? shortsOnly : list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _date(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _open(widget.channelUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('채널 열기'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            '동영상 목록을 불러오지 못했습니다.\n$_error',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      )
                    : _videos.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: const [
                              SizedBox(height: 100),
                              Center(child: Text('표시할 동영상이 없습니다.')),
                            ],
                          )
                        : ListView.builder(
                            itemCount: _videos.length,
                            itemBuilder: (context, i) {
                              final v = _videos[i];
                              return Card(
                                margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _open(v.watchUrl),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: SizedBox(
                                            width: 112,
                                            height: 70,
                                            child: v.thumbnailUrl.isEmpty
                                                ? Container(
                                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                    child: const Icon(Icons.image_not_supported_outlined),
                                                  )
                                                : Image.network(
                                                    v.thumbnailUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(Icons.broken_image_outlined),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                v.title.isEmpty ? '(제목 없음)' : v.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _date(v.publishedAt),
                                                style: Theme.of(context).textTheme.bodySmall,
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
        ],
      ),
    );
  }
}

class _SnsCard extends StatelessWidget {
  final _SnsItem item;
  final VoidCallback onTap;

  const _SnsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                item.color.withValues(alpha: 0.95),
                item.color.withValues(alpha: 0.70),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnsItem {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String url;
  final Widget Function()? routeBuilder;

  const _SnsItem({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.url,
    this.routeBuilder,
  });
}