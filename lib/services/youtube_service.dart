import 'dart:convert';
import 'package:http/http.dart' as http;

class YoutubeVideoLite {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final DateTime publishedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;

  YoutubeVideoLite({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
  });

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
}

class YoutubeTopComment {
  final String text;
  final int likeCount;

  YoutubeTopComment({
    required this.text,
    required this.likeCount,
  });
}

enum YoutubeSort { date, views, likes, comments }

class YoutubeService {
  final String apiKey;
  final String channelId;
  final http.Client _client;

  YoutubeService({
    required this.apiKey,
    required this.channelId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  bool get isConfigured => apiKey.trim().isNotEmpty && channelId.trim().isNotEmpty;

  // ✅ 메모리 캐시
  static final Map<String, _YoutubeCacheEntry<List<YoutubeVideoLite>>> _videoCache = {};
  static final Map<String, _YoutubeCacheEntry<List<YoutubeTopComment>>> _commentCache = {};
  static final Map<String, _YoutubeCacheEntry<String>> _uploadsPlaylistCache = {};

  // ✅ 캐시 유지 시간
  static const Duration _videoCacheTtl = Duration(minutes: 10);
  static const Duration _commentCacheTtl = Duration(minutes: 10);
  static const Duration _playlistCacheTtl = Duration(hours: 6);

  Future<List<YoutubeVideoLite>> fetchLatestVideos({int max = 30}) async {
    if (!isConfigured) return [];

    final safeMax = max.clamp(1, 50);
    final cacheKey = '$channelId|$safeMax';

    final cached = _videoCache[cacheKey];
    if (cached != null && !cached.isExpired(_videoCacheTtl)) {
      return cached.data;
    }

    // 1) 채널의 uploads playlist id 가져오기
    final uploadsPlaylistId = await _fetchUploadsPlaylistId();

    // 2) uploads playlist에서 최신 영상 ID 가져오기
    final playlistUri = Uri.https(
      'www.googleapis.com',
      '/youtube/v3/playlistItems',
      {
        'key': apiKey,
        'playlistId': uploadsPlaylistId,
        'part': 'snippet',
        'maxResults': safeMax.toString(),
      },
    );

    final playlistRes = await _client.get(playlistUri);
    if (playlistRes.statusCode != 200) {
      throw Exception('YouTube playlistItems HTTP ${playlistRes.statusCode}');
    }

    final playlistJson = jsonDecode(playlistRes.body) as Map<String, dynamic>;
    final items = (playlistJson['items'] as List? ?? []);

    final ids = <String>[];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final snippet = (m['snippet'] as Map?) ?? {};
      final resourceId = (snippet['resourceId'] as Map?) ?? {};
      final id = resourceId['videoId']?.toString() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }

    if (ids.isEmpty) {
      _videoCache[cacheKey] = _YoutubeCacheEntry(data: const []);
      return [];
    }

    // 3) videos.list로 상세/통계 조회
    final videosUri = Uri.https(
      'www.googleapis.com',
      '/youtube/v3/videos',
      {
        'key': apiKey,
        'part': 'snippet,statistics',
        'id': ids.join(','),
        'maxResults': '50',
      },
    );

    final videosRes = await _client.get(videosUri);
    if (videosRes.statusCode != 200) {
      throw Exception('YouTube videos HTTP ${videosRes.statusCode}');
    }

    final videosJson = jsonDecode(videosRes.body) as Map<String, dynamic>;
    final vitems = (videosJson['items'] as List? ?? []);

    int toInt(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;

    final out = <YoutubeVideoLite>[];
    for (final it in vitems) {
      final m = it as Map<String, dynamic>;
      final videoId = m['id']?.toString() ?? '';
      if (videoId.isEmpty) continue;

      final snippet = (m['snippet'] as Map?) ?? {};
      final stats = (m['statistics'] as Map?) ?? {};

      final title = (snippet['title']?.toString() ?? '').trim();
      final publishedAt =
          DateTime.tryParse(snippet['publishedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

      final thumbs = (snippet['thumbnails'] as Map?) ?? {};
      final thumbUrl = (thumbs['high'] as Map?)?['url']?.toString() ??
          (thumbs['medium'] as Map?)?['url']?.toString() ??
          (thumbs['default'] as Map?)?['url']?.toString() ??
          '';

      out.add(
        YoutubeVideoLite(
          videoId: videoId,
          title: title,
          thumbnailUrl: thumbUrl,
          publishedAt: publishedAt,
          viewCount: toInt(stats['viewCount']),
          likeCount: toInt(stats['likeCount']),
          commentCount: toInt(stats['commentCount']),
        ),
      );
    }

    out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    _videoCache[cacheKey] = _YoutubeCacheEntry(data: out);
    return out;
  }

  Future<String> _fetchUploadsPlaylistId() async {
    final cached = _uploadsPlaylistCache[channelId];
    if (cached != null && !cached.isExpired(_playlistCacheTtl)) {
      return cached.data;
    }

    final channelUri = Uri.https(
      'www.googleapis.com',
      '/youtube/v3/channels',
      {
        'key': apiKey,
        'id': channelId,
        'part': 'contentDetails',
      },
    );

    final channelRes = await _client.get(channelUri);
    if (channelRes.statusCode != 200) {
      throw Exception('YouTube channels HTTP ${channelRes.statusCode}');
    }

    final channelJson = jsonDecode(channelRes.body) as Map<String, dynamic>;
    final channelItems = (channelJson['items'] as List? ?? []);
    if (channelItems.isEmpty) {
      throw Exception('채널 정보를 찾을 수 없습니다.');
    }

    final channelMap = channelItems.first as Map<String, dynamic>;
    final contentDetails = (channelMap['contentDetails'] as Map?) ?? {};
    final relatedPlaylists = (contentDetails['relatedPlaylists'] as Map?) ?? {};
    final uploadsPlaylistId = relatedPlaylists['uploads']?.toString() ?? '';

    if (uploadsPlaylistId.isEmpty) {
      throw Exception('uploads playlist ID를 찾을 수 없습니다.');
    }

    _uploadsPlaylistCache[channelId] = _YoutubeCacheEntry(data: uploadsPlaylistId);
    return uploadsPlaylistId;
  }

  Future<List<YoutubeTopComment>> fetchTopComments(
    String videoId, {
    int max = 20,
  }) async {
    if (!isConfigured) return [];
    if (videoId.trim().isEmpty) return [];

    final safeMax = max.clamp(1, 100);
    final cacheKey = '$videoId|$safeMax';

    final cached = _commentCache[cacheKey];
    if (cached != null && !cached.isExpired(_commentCacheTtl)) {
      return cached.data;
    }

    final uri = Uri.https(
      'www.googleapis.com',
      '/youtube/v3/commentThreads',
      {
        'key': apiKey,
        'part': 'snippet',
        'videoId': videoId,
        'maxResults': safeMax.toString(),
        'order': 'relevance',
        'textFormat': 'plainText',
      },
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('YouTube comments HTTP ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['items'] as List? ?? []);

    final out = <YoutubeTopComment>[];
    for (final it in items) {
      final m = it as Map<String, dynamic>;
      final snippet = (m['snippet'] as Map?) ?? {};
      final top = (snippet['topLevelComment'] as Map?) ?? {};
      final tsn = (top['snippet'] as Map?) ?? {};

      final text = (tsn['textDisplay']?.toString() ?? '').trim();
      final likeCount = int.tryParse((tsn['likeCount'] ?? '0').toString()) ?? 0;

      if (text.isEmpty) continue;
      out.add(YoutubeTopComment(text: text, likeCount: likeCount));
    }

    out.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    _commentCache[cacheKey] = _YoutubeCacheEntry(data: out);
    return out;
  }

  Future<YoutubeVideoLite?> fetchLatestVideo() async {
    final list = await fetchLatestVideos(max: 1);
    return list.isEmpty ? null : list.first;
  }

  // ✅ 필요 시 강제 초기화
  static void clearCache() {
    _videoCache.clear();
    _commentCache.clear();
    _uploadsPlaylistCache.clear();
  }
}

class _YoutubeCacheEntry<T> {
  final T data;
  final DateTime createdAt;

  _YoutubeCacheEntry({
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(createdAt) > ttl;
  }
}
