import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';

class SaveService {
  static String _highScoreKey(Difficulty difficulty) => 'high_score_${difficulty.name}';

  static Future<int> getHighScore(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey(difficulty)) ?? 0;
  }

  /// Saves [score] as the new high score if it beats the stored one.
  /// Returns true when a new high score was set.
  static Future<bool> submitScore(Difficulty difficulty, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _highScoreKey(difficulty);
    final current = prefs.getInt(key) ?? 0;
    if (score <= current) return false;
    await prefs.setInt(key, score);
    return true;
  }
}
