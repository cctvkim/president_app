import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/content_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _looksLikeHtml(String s) {
  final t = s.trimLeft().toLowerCase();
  return t.startsWith('<!doctype html') || t.startsWith('<html') || t.contains('<title>');
}

class KtvApi {
  final String rawServiceKey;
  final http.Client _client;

  KtvApi(this.rawServiceKey, {http.Client? client}) : _client = client ?? http.Client();

  static const _cardBase = 'https://apis.data.go.kr/1371037/ktvCardNews/cardNewsList';
  static const _videoBase = 'https://apis.data.go.kr/1371037/ktvVideo/videoList';

  static const presidentKeywords = ['이재명', '이 대통령', '대통령'];

  Uri _uri(String base, Map<String, String> qp) {
    final serviceKey = Uri.encodeQueryComponent(rawServiceKey);
    return Uri.parse(base).replace(queryParameters: {
      'serviceKey': serviceKey,
      ...qp,
    });
  }

  // ✅ KTV 피드 캐시(마지막 성공값) - 네트워크 오류 시 폴백용
  static const _feedCacheKey = 'ktv_president_feed_cache_v1';
  static const _feedCacheTimeKey = 'ktv_president_feed_cache_time_v1';
  static const int _feedCacheTtlSeconds = 60 * 30; // 30분

  Future<List<ContentItem>?> _loadFeedCacheIfFresh() async {
    final sp = await SharedPreferences.getInstance();
    final ts = sp.getInt(_feedCacheTimeKey);
    final raw = sp.getString(_feedCacheKey);
    if (ts == null || raw == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - ts > _feedCacheTtlSeconds) return null;

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ContentItem(
                id: e['id'] as String,
                source: SourceType.values.firstWhere((s) => s.name == (e['source'] as String)),
                title: e['title'] as String,
                description: e['description'] as String,
                publishedAt: DateTime.tryParse(e['publishedAt'] as String) ?? DateTime.fromMillisecondsSinceEpoch(0),
                thumbnailUrl: e['thumbnailUrl'] as String,
                linkUrl: e['linkUrl'] as String,
                viewCnt: e['viewCnt'] as int?,
                programName: e['programName'] as String?,
                categoryName: e['categoryName'] as String?,
              ))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFeedCache(List<ContentItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final raw = jsonEncode(items
        .map((it) => {
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
            })
        .toList());

    await sp.setString(_feedCacheKey, raw);
    await sp.setInt(_feedCacheTimeKey, now);
  }

  Future<Map<String, dynamic>> _getJsonWithRetry(
    Uri uri, {
    required http.Client client,
    int retries = 2,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final res = await client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'president_app/1.0',
          },
        ).timeout(const Duration(seconds: 10));

        final body = res.body;

        if (res.statusCode != 200) {
          if (_looksLikeHtml(body)) {
            throw Exception('KTV 서버 오류(HTML 응답): HTTP ${res.statusCode}');
          }
          throw Exception('KTV 서버 오류: HTTP ${res.statusCode}');
        }

        if (_looksLikeHtml(body)) {
          throw Exception('KTV 서버 오류(HTML 응답)');
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('KTV 응답 형식 오류(JSON map 아님)');
        }
        return decoded;
      } catch (e) {
        if (attempt == retries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * (1 << attempt)));
      }
    }
    throw Exception('unreachable');
  }

  Future<List<ContentItem>> fetchPresidentFeed({int rows = 50}) async {
    try {
      final results = await Future.wait([
        _fetchCardNews(rows: rows),
        _fetchVideos(rows: rows),
      ]);

      final merged = [...results[0], ...results[1]];
      final filtered = merged.where(_isPresidentContent).toList();
      final deduped = _dedupe(filtered);
      deduped.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      await _saveFeedCache(deduped);
      return deduped;
    } catch (_) {
      final cached = await _loadFeedCacheIfFresh();
      if (cached != null && cached.isNotEmpty) {
        cached.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        return cached;
      }
      rethrow;
    }
  }
  Future<List<ContentItem>> _fetchCardNews({int rows = 50, int page = 1}) async {
    final uri = _uri(_cardBase, {
      'pageNo': '$page',
      'numOfRows': '$rows',
      'type': 'json',
    });

    // ✅ 여기 변경: 직접 get + jsonDecode 제거
    final decoded = await _getJsonWithRetry(uri, client: _client);

    final items = _extractItems(decoded);

    return items.map((m) {
      final id = '${m['cardId'] ?? ''}';
      final title = _asString(m['title']);
      final content = _cleanText(_asString(m['content']));
      final imgUrl = _asString(m['imgUrl']);
      final linkUrl = _asString(m['linkUrl']);
      final viewCnt = _toInt(m['viewCnt']);

      final publishedAt = _parseDate(
        _asString(m['createDate']).isNotEmpty ? _asString(m['createDate']) : _asString(m['registDate']),
      );

      return ContentItem(
        id: id,
        source: SourceType.cardNews,
        title: title,
        description: content,
        publishedAt: publishedAt,
        thumbnailUrl: _fixMaybeRelativeUrl(imgUrl),
        linkUrl: linkUrl,
        viewCnt: viewCnt,
      );
    }).toList();
  }

  Future<List<ContentItem>> _fetchVideos({int rows = 50, int page = 1}) async {
    final uri = _uri(_videoBase, {
      'pageNo': '$page',
      'numOfRows': '$rows',
      'type': 'json',
    });

    // ✅ 여기 변경: 직접 get + jsonDecode 제거
    final decoded = await _getJsonWithRetry(uri, client: _client);

    final items = _extractItems(decoded);

    return items.map((m) {
      final id = '${m['contentId'] ?? ''}';
      final title = _asString(m['title']);
      final desc = _cleanText(_asString(m['description']));
      final imgUrl = _asString(m['imgUrl']);
      final linkUrl = _asString(m['linkUrl']);
      final viewCnt = _toInt(m['viewCnt']);

      final programName = _asString(m['programName']);
      final categoryName = _asString(m['categoryName']);

      final publishedAt = _parseDate(
        _asString(m['broadcastDate']).isNotEmpty ? _asString(m['broadcastDate']) : _asString(m['registDate']),
      );

      return ContentItem(
        id: id,
        source: SourceType.video,
        title: title,
        description: desc,
        publishedAt: publishedAt,
        thumbnailUrl: _fixMaybeRelativeUrl(imgUrl),
        linkUrl: linkUrl,
        viewCnt: viewCnt,
        programName: programName.isEmpty ? null : programName,
        categoryName: categoryName.isEmpty ? null : categoryName,
      );
    }).toList();
  }

  bool _isPresidentContent(ContentItem item) {
    final hay = '${item.title} ${item.description}';
    return presidentKeywords.any(hay.contains);
  }

  List<ContentItem> _dedupe(List<ContentItem> items) {
    final seen = <String>{};
    final out = <ContentItem>[];

    for (final it in items) {
      final key = it.linkUrl.isNotEmpty ? 'url::${it.linkUrl}' : it.uniqueKey;
      if (seen.add(key)) out.add(it);
    }
    return out;
  }

  List<Map<String, dynamic>> _extractItems(dynamic decoded) {
    try {
      if (decoded is Map) {
        final response = decoded['response'];
        final body = (response is Map) ? response['body'] : null;
        final items = (body is Map) ? body['items'] : null;
        final item = (items is Map) ? items['item'] : null;

        if (item is List) {
          return item.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
        if (item is Map) return [item.cast<String, dynamic>()];
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  String _asString(dynamic v) => v == null ? '' : v.toString();

  int? _toInt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  DateTime _parseDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);

    final iso = DateTime.tryParse(t);
    if (iso != null) return iso;

    if (t.length == 8 && int.tryParse(t) != null) {
      final y = int.parse(t.substring(0, 4));
      final m = int.parse(t.substring(4, 6));
      final d = int.parse(t.substring(6, 8));
      return DateTime(y, m, d);
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _cleanText(String s) {
    var t = s;
    t = t.replaceAll('<br>', '\n').replaceAll('<br/>', '\n').replaceAll('<br />', '\n');
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');
    t = t.replaceAll('&amp;', '&');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return t;
  }

  String _fixMaybeRelativeUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    return 'https://www.ktv.go.kr$u';
  }
}
