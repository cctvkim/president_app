import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/youtube_service.dart';

class HomeYoutubeCard extends StatefulWidget {
  final YoutubeService yt;
  final Color headerColor;

  const HomeYoutubeCard({
    super.key,
    required this.yt,
    this.headerColor = const Color(0xFFFF1744),
  });

  @override
  State<HomeYoutubeCard> createState() => _HomeYoutubeCardState();
}

class _HomeYoutubeCardState extends State<HomeYoutubeCard> {
  bool _loading = true;
  String? _error;

  YoutubeVideoLite? _video;

  @override
  void initState() {
    super.initState();
    _loadYoutube();
  }

  Future<void> _loadYoutube() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final video = await widget.yt.fetchLatestVideo();
      setState(() {
        _video = video;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openYoutube(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // ✅ 추가
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(color: widget.headerColor),
            const SizedBox(height: 10),

            // ✅ 핵심: Body는 남은 높이만 사용 (overflow 방지)
            Expanded(
              child: ClipRect(
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_error != null) {
      return _MiniError(error: _error!, onRetry: _loadYoutube);
    }

    if (_video == null) {
      return const _Empty();
    }

    return _Body(
      color: widget.headerColor,
      video: _video!,
      onOpen: _openYoutube,
    );
  }
}

class _Header extends StatelessWidget {
  final Color color;

  const _Header({required this.color});

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
            child: Icon(Icons.ondemand_video_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'YouTube',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Color color;
  final YoutubeVideoLite video;
  final Future<void> Function(String url) onOpen;

  const _Body({
    required this.color,
    required this.video,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = video.title.trim();
    final thumb = video.thumbnailUrl.trim();
    final url = video.watchUrl;

    final date = _date(video.publishedAt);
    final meta = '$date · 👁 ${_num(video.viewCount)} · 👍 ${_num(video.likeCount)} · 💬 ${_num(video.commentCount)}';

    // ✅ 카드 전체 탭 -> 유튜브 이동 (버튼 없음)
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onOpen(url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 높이를 고정으로 줄여서 안정화
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 92,
              width: double.infinity,
              child: thumb.isEmpty
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                    )
                  : Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            title.isEmpty ? '(제목 없음)' : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),

          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),

          // ✅ 남는 공간은 그냥 비워서 overflow 방지
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  static String _date(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return '';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  static String _num(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

class _MiniError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _MiniError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('다시 시도'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.outline),
    );
  }
}
