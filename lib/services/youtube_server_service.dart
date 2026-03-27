import 'dart:convert';
import 'package:http/http.dart' as http;

class YoutubeServerVideoLite {
  final String videoId;
  final String title;
  final String description;
  final String thumbnailUrl;
  final DateTime publishedAt;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final String watchUrl;

  YoutubeServerVideoLite({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.watchUrl,
  });

  factory YoutubeServerVideoLite.fromJson(Map<String, dynamic> json) {
    return YoutubeServerVideoLite(
      videoId: json['videoId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      viewCount: int.tryParse((json['viewCount'] ?? '0').toString()) ?? 0,
      likeCount: int.tryParse((json['likeCount'] ?? '0').toString()) ?? 0,
      commentCount: int.tryParse((json['commentCount'] ?? '0').toString()) ?? 0,
      watchUrl: json['watchUrl']?.toString() ?? '',
    );
  }
}

class YoutubeServerFeedRow {
  final String channelName;
  final YoutubeServerVideoLite video;

  YoutubeServerFeedRow({
    required this.channelName,
    required this.video,
  });
}

class YoutubeServerService {
  final String baseUrl;

  const YoutubeServerService({
    required this.baseUrl,
  });

  Future<List<YoutubeServerVideoLite>> fetchLatestVideos({
    required String channelId,
    int max = 15,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v1/youtube/latest?channel_id=$channelId&max_results=$max',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Server latest HTTP ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['items'] as List? ?? []);

    return items.map((e) => YoutubeServerVideoLite.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<YoutubeServerFeedRow>> fetchMergedFeed() async {
    final uri = Uri.parse('$baseUrl/v1/youtube/feed');

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Server feed HTTP ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['items'] as List? ?? []);

    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return YoutubeServerFeedRow(
        channelName: m['channelName']?.toString() ?? '',
        video: YoutubeServerVideoLite.fromJson(m),
      );
    }).toList();
  }
}

