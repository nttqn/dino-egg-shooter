import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../models/game_mode.dart';

class SaveService {
  static String _highScoreKey(Difficulty difficulty, GameMode mode) =>
      'high_score_${difficulty.name}_${mode.name}';

  static Future<int> getHighScore(Difficulty difficulty, GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey(difficulty, mode)) ?? 0;
  }

  /// Saves [score] as the new high score if it beats the stored one.
  /// Returns true when a new high score was set.
  static Future<bool> submitScore(Difficulty difficulty, GameMode mode, int score) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _highScoreKey(difficulty, mode);
    final current = prefs.getInt(key) ?? 0;
    if (score <= current) return false;
    await prefs.setInt(key, score);
    return true;
  }
}
