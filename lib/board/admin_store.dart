import 'package:shared_preferences/shared_preferences.dart';

class AdminStore {
  static const _key = "jason878~6";

  static Future<void> save(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, token);
  }

  static Future<String?> get() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_key);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
