import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dino_collection.dart';
import 'player_stats.dart';

/// The parts of local storage worth keeping across devices, as a JSON
/// snapshot for Play Games Saved Games, and how two snapshots combine.
///
/// Every counter only ever grows (hatch counts, high scores, lifetime
/// stats), so merging takes the larger value per key and the union of
/// unlocked achievements — progress from either device is never lost.
class CloudProgress {
  static const version = 1;
  static const _selectedKey = 'dino_selected';
  static const _counterPrefixes = ['dino_hatch_', 'high_score_', 'stat_'];

  static bool _isCounter(String key) => _counterPrefixes.any(key.startsWith);

  static Map<String, dynamic> export(SharedPreferences prefs) {
    final counters = <String, int>{
      for (final key in prefs.getKeys())
        if (_isCounter(key) && prefs.get(key) is int) key: prefs.getInt(key)!,
    };
    return {
      'v': version,
      'counters': counters,
      'unlocked': prefs.getStringList(PlayerStats.unlockedKey) ?? const <String>[],
      'selected': prefs.getString(_selectedKey),
    };
  }

  /// Null for anything this version can't read, so it's left untouched.
  static Map<String, dynamic>? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return null;
      final v = data['v'];
      if (v is! int || v > version) return null;
      return data;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> merge(Map<String, dynamic> local, Map<String, dynamic> cloud) {
    final counters = <String, int>{};
    for (final source in [cloud, local]) {
      final map = source['counters'];
      if (map is! Map) continue;
      map.forEach((key, value) {
        if (key is String && value is int && _isCounter(key)) {
          final current = counters[key];
          counters[key] = current == null || value > current ? value : current;
        }
      });
    }
    List<String> names(Map<String, dynamic> m) => (m['unlocked'] as List?)?.whereType<String>().toList() ?? const [];
    return {
      'v': version,
      'counters': counters,
      'unlocked': {...names(local), ...names(cloud)}.toList()..sort(),
      'selected': local['selected'] ?? cloud['selected'],
    };
  }

  /// Writes a merged snapshot into local storage and reloads what's cached
  /// in memory from it.
  static Future<void> apply(SharedPreferences prefs, Map<String, dynamic> data) async {
    final counters = data['counters'];
    if (counters is Map) {
      for (final entry in counters.entries) {
        if (entry.key is String && entry.value is int) await prefs.setInt(entry.key as String, entry.value as int);
      }
    }
    await prefs.setStringList(PlayerStats.unlockedKey, (data['unlocked'] as List?)?.whereType<String>().toList() ?? []);
    final selected = data['selected'];
    if (selected is String) await prefs.setString(_selectedKey, selected);

    // A round may be in progress with counters not yet flushed to storage.
    final pops = PlayerStats.eggsPopped;
    final skills = PlayerStats.skillsUsed;
    await DinoCollection.init();
    await PlayerStats.load();
    if (pops > PlayerStats.eggsPopped) PlayerStats.eggsPopped = pops;
    if (skills > PlayerStats.skillsUsed) PlayerStats.skillsUsed = skills;
  }
}
