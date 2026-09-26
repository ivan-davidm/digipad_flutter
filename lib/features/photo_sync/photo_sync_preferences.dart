import 'package:shared_preferences/shared_preferences.dart';

class PhotoSyncPreferences {
  static const _kMyTotemName = 'ps_my_totem_name';
  static const _kMyClientName = 'ps_my_client_name';
  static const _kLastTotemName = 'ps_last_totem_name';
  static const _kLastTotemHosts = 'ps_last_totem_hosts';

  /// Returns the stable advertising name for this Totem device.
  /// Generated once and persisted — same QR across restarts.
  Future<String> getOrCreateTotemName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kMyTotemName);
    if (saved != null) return saved;
    final suffix = (DateTime.now().millisecondsSinceEpoch % 0xFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    final name = 'Totem-$suffix';
    await prefs.setString(_kMyTotemName, name);
    return name;
  }

  /// Returns the stable name this client device advertises during discovery.
  Future<String> getOrCreateClientName() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kMyClientName);
    if (saved != null) return saved;
    final suffix = (DateTime.now().millisecondsSinceEpoch % 0xFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    final name = 'Operador-$suffix';
    await prefs.setString(_kMyClientName, name);
    return name;
  }

  Future<String?> loadLastTotemName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastTotemName);
  }

  Future<void> saveLastTotemName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastTotemName, name);
  }

  Future<void> clearLastTotemName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastTotemName);
    await prefs.remove(_kLastTotemHosts);
  }

  /// Last known LAN `http://ip:port` hosts for the paired Totem (fast reconnect).
  Future<void> saveLastTotemHosts(List<String> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    if (hosts.isEmpty) {
      await prefs.remove(_kLastTotemHosts);
    } else {
      await prefs.setStringList(_kLastTotemHosts, hosts);
    }
  }

  Future<List<String>> loadLastTotemHosts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kLastTotemHosts) ?? const [];
  }
}
