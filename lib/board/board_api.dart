import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'device_service.dart';

class BoardApi {
  static const String baseUrl = "http://13.209.167.188:8001";

  // 로컬 차단 저장 키
  static const String _spBlockedKey = "board_blocked_uuids";

  static Future<Map<String, String>> _headers() async {
    final uuid = await DeviceService.getOrCreateUuid();
    return {
      "Content-Type": "application/json",
      "X-Device-UUID": uuid,
    };
  }

  

  static Future<Map<String, String>> _deviceHeaders() async {
    final uuid = await DeviceService.getOrCreateUuid();
    return {
      "X-Device-UUID": uuid,
    };
  }

  // -------------------------
  // 차단(로컬 우선, 서버 있으면 서버도)
  // -------------------------

  static Future<Set<String>> _getBlockedLocal() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_spBlockedKey) ?? <String>[];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> _setBlockedLocal(Set<String> uuids) async {
    final sp = await SharedPreferences.getInstance();
    final list = uuids.toList()..sort();
    await sp.setStringList(_spBlockedKey, list);
  }

  /// 서버에 차단 API가 있으면 서버도 호출, 없으면 로컬만으로 동작
  static Future<void> blockUser(String targetUuid) async {
    final u = targetUuid.trim();
    if (u.isEmpty) return;

    // 1) 로컬 저장
    final blocked = await _getBlockedLocal();
    blocked.add(u);
    await _setBlockedLocal(blocked);

    // 2) 서버 시도 (없으면 무시)
    try {
      final uri = Uri.parse("$baseUrl/v1/blocks/$u");
      final res = await http.post(uri, headers: await _headers());
      // 서버가 없거나 정책상 다를 수 있으니, 200/201/204만 성공 처리
      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) return;
      // 404/405면 미구현이므로 무시
      if (res.statusCode == 404 || res.statusCode == 405) return;
    } catch (_) {
      // 네트워크/서버 에러는 로컬 기능에는 영향 없게 무시
    }
  }

  static Future<void> unblockUser(String targetUuid) async {
    final u = targetUuid.trim();
    if (u.isEmpty) return;

    // 1) 로컬 삭제
    final blocked = await _getBlockedLocal();
    blocked.remove(u);
    await _setBlockedLocal(blocked);

    // 2) 서버 시도
    try {
      final uri = Uri.parse("$baseUrl/v1/blocks/$u");
      final res = await http.delete(uri, headers: await _headers());
      if (res.statusCode == 200 || res.statusCode == 204) return;
      if (res.statusCode == 404 || res.statusCode == 405) return;
    } catch (_) {}
  }

  /// 차단 목록(서버가 있으면 서버 우선, 없으면 로컬)
  static Future<List<String>> listBlockedUsers() async {
    // 1) 서버 시도
    try {
      final uri = Uri.parse("$baseUrl/v1/blocks");
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // 서버 포맷이 ["uuid", ...] 또는 {"items":[...]} 둘 다 대응
        if (data is List) {
          final items = data.map((e) => e.toString()).toList();
          // 로컬에도 동기화
          await _setBlockedLocal(items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet());
          items.sort();
          return items;
        }
        if (data is Map && data["items"] is List) {
          final items = (data["items"] as List).map((e) => e.toString()).toList();
          await _setBlockedLocal(items.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet());
          items.sort();
          return items;
        }
      }
      if (res.statusCode == 404 || res.statusCode == 405) {
        // 미구현 → 로컬
      }
    } catch (_) {}

    // 2) 로컬
    final local = (await _getBlockedLocal()).toList()..sort();
    return local;
  }

  static Future<bool> isBlocked(String uuid) async {
    final blocked = await _getBlockedLocal();
    return blocked.contains(uuid.trim());
  }

  static Future<List<Map<String, dynamic>>> _filterBlocked(List<Map<String, dynamic>> items) async {
    final blocked = await _getBlockedLocal();
    if (blocked.isEmpty) return items;

    bool isItemBlocked(Map<String, dynamic> it) {
      // 서버/클라에서 author uuid 키가 무엇인지 확실치 않아서 여러 키를 시도
      final v = (it["author_uuid"] ?? it["device_uuid"] ?? it["writer_uuid"] ?? it["user_uuid"])?.toString();
      if (v == null || v.trim().isEmpty) return false;
      return blocked.contains(v.trim());
    }

    return items.where((it) => !isItemBlocked(it)).toList();
  }

  // -------------------------
  // 기존 API
  // -------------------------

  static Future<void> reactComment(int commentId) async {
    final uri = Uri.parse('$baseUrl/v1/comments/$commentId/like');
    final res = await http.post(uri, headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception('like comment failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> reportPost(int postId, String reason) async {
    final uri = Uri.parse('$baseUrl/v1/posts/$postId/report');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({"reason": reason}),
    );
    if (res.statusCode != 200) {
      throw Exception('reportPost failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> reportComment(int commentId, String reason) async {
    final uri = Uri.parse('$baseUrl/v1/comments/$commentId/report');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({"reason": reason}),
    );
    if (res.statusCode != 200) {
      throw Exception('reportComment failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> listPosts({
    String sort = "latest",
    int page = 1,
    int size = 20,
  }) async {
    final uri = Uri.parse("$baseUrl/v1/posts?sort=$sort&page=$page&size=$size");
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("listPosts failed: ${res.statusCode} ${res.body}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data["items"] as List).cast<dynamic>();
    final list = items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return await _filterBlocked(list);
  }



  static Future<Map<String, dynamic>> createPost(
    String title,
    String content, {
    XFile? image,
  }) async {
    final uri = Uri.parse("$baseUrl/v1/posts");

    if (image == null) {
      final res = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode({
          "title": title,
          "content": content,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("createPost failed: ${res.statusCode} ${res.body}");
      }
      return (jsonDecode(res.body) as Map).cast<String, dynamic>();
    }

    final req = http.MultipartRequest("POST", uri);
    req.headers.addAll(await _deviceHeaders());
    req.fields["title"] = title;
    req.fields["content"] = content;
    req.files.add(await http.MultipartFile.fromPath("image", image.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception("createPost failed: ${streamed.statusCode} $body");
    }

    return (jsonDecode(body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updatePost(
    int postId,
    String title,
    String content,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/v1/posts/$postId'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'content': content,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('updatePost failed: ${res.statusCode} ${res.body}');
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getPost(int postId) async {
    final uri = Uri.parse("$baseUrl/v1/posts/$postId");
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("getPost failed: ${res.statusCode} ${res.body}");
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> listComments(int postId, {String sort = "latest"}) async {
    final uri = Uri.parse("$baseUrl/v1/posts/$postId/comments?sort=$sort");
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("listComments failed: ${res.statusCode} ${res.body}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data["items"] as List).cast<dynamic>();
    final list = items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return await _filterBlocked(list);
  }

  static Future<void> adminDeletePost(int postId, String adminToken) async {
    final uri = Uri.parse('$baseUrl/v1/admin/posts/$postId/delete');

    final res = await http.post(
      uri,
      headers: {
        "X-Admin-Token": adminToken,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('adminDeletePost failed: ${res.statusCode} ${res.body}');
    }
  }


  static Future<Map<String, dynamic>> createComment(int postId, String content, {int? parentId}) async {
    final uri = Uri.parse("$baseUrl/v1/posts/$postId/comments");
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({"content": content, "parent_id": parentId}),
    );
    if (res.statusCode != 200) {
      throw Exception("createComment failed: ${res.statusCode} ${res.body}");
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> reactPost(int postId, int value) async {
    final uri = Uri.parse("$baseUrl/v1/posts/$postId/reaction");
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({"value": value}),
    );
    if (res.statusCode != 200) {
      throw Exception("reactPost failed: ${res.statusCode} ${res.body}");
    }
    return (jsonDecode(res.body) as Map).cast<String, dynamic>();
  }
}
