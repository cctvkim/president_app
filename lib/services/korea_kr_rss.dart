import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/content_item.dart';

class KoreaKrRssService {
  final String feedUrl;
  final http.Client _client;

  KoreaKrRssService({required this.feedUrl, http.Client? client}) : _client = client ?? http.Client();

  factory KoreaKrRssService.defaultPresident({http.Client? client}) {
    return KoreaKrRssService(
      feedUrl: 'https://www.korea.kr/rss/president.xml',
      client: client,
    );
  }

  // ===== 캐시/네트워크 설정 =====
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxAttempts = 3;
  static const Duration _baseBackoff = Duration(milliseconds: 400);
  static const int _cacheTtlSeconds = 60 * 60 * 6; // 6시간 (원하면 1시간 등으로 줄여도 됨)

  String get _cacheKeyData => 'rss_cache_data_${_safeKey(feedUrl)}';
  String get _cacheKeyTime => 'rss_cache_time_${_safeKey(feedUrl)}';

  static String _safeKey(String s) {
    // url을 키로 쓰기 위해 안전하게 인코딩
    return base64UrlEncode(utf8.encode(s));
  }

  Future<List<ContentItem>> fetch({int limit = 50}) async {
    // 1) 네트워크 시도 (retry + timeout)
    Exception? lastErr;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final res = await _client.get(Uri.parse(feedUrl)).timeout(_timeout);

        if (res.statusCode != 200) {
          throw Exception('RSS HTTP ${res.statusCode}');
        }

        final body = utf8.decode(res.bodyBytes); // 한글 깨짐 방지
        final doc = XmlDocument.parse(body);

        final out = <ContentItem>[];
        for (final it in doc.findAllElements('item').take(limit)) {
          final title = _cdata(it, 'title');
          final link = _cdata(it, 'link');
          final pubDate = _text(it, 'pubDate');
          final dcDate = _text(it, 'dc:date');

          out.add(ContentItem(
            id: link.isNotEmpty ? link : title,
            source: SourceType.rss,
            title: title,
            description: '',
            publishedAt: _parseDate(pubDate, dcDate),
            thumbnailUrl: '',
            linkUrl: link,
            viewCnt: null,
            programName: null,
            categoryName: null,
          ));
        }

        out.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

        // ✅ 성공하면 캐시 저장 (정렬된 결과 저장)
        await _saveCache(out);

        return out;
      } catch (e) {
        lastErr = e is Exception ? e : Exception(e.toString());

        // 마지막 시도면 탈출해서 캐시로 폴백
        if (attempt == _maxAttempts) break;

        // backoff: 0.4s, 0.9s, 1.6s 정도로 증가
        final wait = Duration(
          milliseconds: (_baseBackoff.inMilliseconds * (attempt * attempt)).toInt(),
        );
        await Future.delayed(wait);
      }
    }

    // 2) 여기까지 왔으면 네트워크 실패 → 캐시 폴백
    final cached = await _loadCacheIfFresh();
    if (cached != null && cached.isNotEmpty) {
      // limit 적용 + 최신순(이미 저장 시 정렬되지만 안전하게)
      cached.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return cached.take(limit).toList();
    }

    // 3) 캐시도 없으면 진짜 에러
    throw lastErr ?? Exception('RSS fetch failed (no cache)');
  }

  Future<void> _saveCache(List<ContentItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final raw = jsonEncode(items.map(_toJson).toList());
    await sp.setString(_cacheKeyData, raw);
    await sp.setInt(_cacheKeyTime, now);
  }

  Future<List<ContentItem>?> _loadCacheIfFresh() async {
    final sp = await SharedPreferences.getInstance();
    final ts = sp.getInt(_cacheKeyTime);
    final raw = sp.getString(_cacheKeyData);

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

  Map<String, dynamic> _toJson(ContentItem it) => {
        'id': it.id,
        'title': it.title,
        'linkUrl': it.linkUrl,
        'publishedAt': it.publishedAt.toIso8601String(),
      };

  ContentItem _fromJson(Map<String, dynamic> m) => ContentItem(
        id: (m['id'] as String?) ?? '',
        source: SourceType.rss,
        title: (m['title'] as String?) ?? '',
        description: '',
        publishedAt: DateTime.tryParse((m['publishedAt'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        thumbnailUrl: '',
        linkUrl: (m['linkUrl'] as String?) ?? '',
        viewCnt: null,
        programName: null,
        categoryName: null,
      );

  DateTime _parseDate(String pubDate, String dcDate) {
    final d1 = dcDate.trim();
    if (d1.isNotEmpty) {
      final iso = DateTime.tryParse(d1);
      if (iso != null) return iso.toLocal();
    }

    final p = pubDate.trim();
    if (p.isNotEmpty) {
      try {
        return HttpDate.parse(p).toLocal();
      } catch (_) {}
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _text(XmlElement parent, String tag) {
    final els = parent.findElements(tag);
    if (els.isEmpty) return '';
    return els.first.text.trim();
  }

  String _cdata(XmlElement parent, String tag) {
    final els = parent.findElements(tag);
    if (els.isEmpty) return '';
    return els.first.text.trim();
  }
}
