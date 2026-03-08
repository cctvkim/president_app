// lib/board/board_block_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class BoardBlockStore {
  static const String _key = 'board_blocked_uuids';

  static Future<List<String>> list() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getStringList(_key) ?? <String>[];
    // 중복 제거 + 공백 제거
    final set = <String>{};
    for (final s in raw) {
      final v = s.trim();
      if (v.isNotEmpty) set.add(v);
    }
    return set.toList()..sort();
  }

  static Future<bool> isBlocked(String uuid) async {
    final u = uuid.trim();
    if (u.isEmpty) return false;
    final items = await list();
    return items.contains(u);
  }

  static Future<void> block(String uuid) async {
    final u = uuid.trim();
    if (u.isEmpty) return;

    final sp = await SharedPreferences.getInstance();
    final items = await list();
    if (!items.contains(u)) items.add(u);
    await sp.setStringList(_key, items);
  }

  static Future<void> unblock(String uuid) async {
    final u = uuid.trim();
    if (u.isEmpty) return;

    final sp = await SharedPreferences.getInstance();
    final items = await list();
    items.removeWhere((x) => x == u);
    await sp.setStringList(_key, items);
  }
}
