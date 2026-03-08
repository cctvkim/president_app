import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeApi {
  /// ✅ 여기에 넣는다 (1)
  static const String apiKey = 'AIzaSyCbnLIvhOOrdn9EcTcsvbi_ch-0NFOIF0g';

  /// ✅ 여기에 넣는다 (2)
  static const String channelId = 'UCNJM6dqu70Qr6VaseiW1Org'; // 이재명tv 채널 ID

  final http.Client _client = http.Client();

  /// 최신 영상 1개 (홈 우측 하단용)
  Future<Map<String, dynamic>> fetchLatestVideo() async {
    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&channelId=$channelId'
      '&order=date'
      '&maxResults=1'
      '&type=video'
      '&key=$apiKey',
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('YouTube API error ${res.statusCode}');
    }

    final json = jsonDecode(res.body);
    return json['items'][0];
  }

  /// 조회수 많은 영상
  Future<List<Map<String, dynamic>>> fetchTopVideos({int max = 5}) async {
    final uri = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search'
      '?part=snippet'
      '&channelId=$channelId'
      '&order=viewCount'
      '&maxResults=$max'
      '&type=video'
      '&key=$apiKey',
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('YouTube API error ${res.statusCode}');
    }

    final json = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(json['items']);
  }
}
