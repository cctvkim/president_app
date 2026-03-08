import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _key = 'device_uuid';

  static Future<String> getOrCreateUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final uuid = const Uuid().v4();
    await prefs.setString(_key, uuid);
    return uuid;
  }
}
