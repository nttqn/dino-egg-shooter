import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_achievement.dart';
import 'dino_collection.dart';
import 'play_games.dart';

/// Lifetime counters and unlocked achievements, kept on the device so they
/// count even when the player isn't signed in to Play Games (they're synced
/// up on the next sign-in). Counters are bumped in memory during a round and
/// written by [flush] at round end, not on every pop.
class PlayerStats {
  static const popsKey = 'stat_eggs_popped';
  static const skillsKey = 'stat_skills_used';
  static const unlockedKey = 'achievements_unlocked';

  static int eggsPopped = 0;
  static int skillsUsed = 0;
  static final Set<GameAchievement> unlocked = {};

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      eggsPopped = prefs.getInt(popsKey) ?? 0;
      skillsUsed = prefs.getInt(skillsKey) ?? 0;
      final names = prefs.getStringList(unlockedKey) ?? const [];
      unlocked
        ..clear()
        ..addAll(GameAchievement.values.where((a) => names.contains(a.name)));
    } catch (_) {}
  }

  static int get totalHatched => DinoCollection.hatchCounts.value.values.fold(0, (sum, n) => sum + n);

  /// Progress toward an incremental achievement, capped at its step count.
  static int progressOf(GameAchievement achievement) {
    final value = switch (achievement) {
      GameAchievement.hatch25 => totalHatched,
      GameAchievement.skill50 => skillsUsed,
      GameAchievement.pop1000 => eggsPopped,
      _ => 0,
    };
    return value < achievement.steps ? value : achievement.steps;
  }

  static void addPops(int count) => eggsPopped += count;

  static void addSkillUse() {
    skillsUsed++;
    unlock(GameAchievement.firstSkill);
  }

  static void unlock(GameAchievement achievement) {
    if (achievement.incremental || !unlocked.add(achievement)) return;
    _write((prefs) => prefs.setStringList(unlockedKey, [for (final a in unlocked) a.name]));
    PlayGames.unlocked(achievement);
  }

  /// Saves the counters and pushes them (and scores) to Play Games.
  static Future<void> flush() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(popsKey, eggsPopped);
      await prefs.setInt(skillsKey, skillsUsed);
    } catch (_) {}
    PlayGames.progressChanged();
  }

  static void _write(Future<bool> Function(SharedPreferences prefs) write) {
    SharedPreferences.getInstance().then(write).catchError((_) => false);
  }
}
