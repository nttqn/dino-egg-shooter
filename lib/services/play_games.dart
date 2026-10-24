import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as pgs;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/difficulty.dart';
import '../models/game_achievement.dart';
import '../models/game_mode.dart';
import 'cloud_progress.dart';
import 'player_stats.dart';
import 'save_service.dart';

/// Google Play Games: sign-in, leaderboards, achievements, and a cloud copy
/// of the player's progress (Saved Games). Android only — the iOS build
/// ("Pop-a-Saurus") doesn't use Game Center.
///
/// Nothing here ever blocks play. Every platform call has a timeout as well
/// as a try/catch: with no native handler (tests, or a device without Play
/// Services) the plugin's future can simply never complete. The timeout is
/// generous because a first-ever sign-in can show a consent sheet the player
/// has to tap.
class PlayGames {
  PlayGames._();

  // IDs from Play Console (Play Games Services → the game). Empty = not
  // created yet; that board or achievement is skipped.
  static const Map<GameMode, String> _scoreBoards = {
    GameMode.normal: '',
    GameMode.endless: '',
    GameMode.timeTrial: '',
  };
  static const _hatchBoard = '';

  static const Map<GameAchievement, String> _achievementIds = {
    GameAchievement.firstHatch: '',
    GameAchievement.fullPark: '',
    GameAchievement.hatch25: '',
    GameAchievement.firstSkill: '',
    GameAchievement.skill50: '',
    GameAchievement.pop1000: '',
    GameAchievement.bigCombo: '',
    GameAchievement.level5: '',
    GameAchievement.level10: '',
    GameAchievement.timeTrial3000: '',
  };

  static const _saveName = 'progress';
  static const _timeout = Duration(seconds: 12);

  static final ValueNotifier<bool> signedIn = ValueNotifier<bool>(false);

  /// Whether Play Games buttons are worth showing on this platform.
  static bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Timer? _pending;
  static Future<void>? _syncing;

  /// Signs in and brings this device, the cloud and Play Games up to date.
  /// Called once at launch; not awaited.
  static Future<void> start() async {
    if (!available || signedIn.value) return;
    try {
      await pgs.GameAuth.signIn().timeout(_timeout);
    } catch (_) {
      return;
    }
    signedIn.value = true;
    await _sync();
  }

  /// After a round or anything else worth syncing; debounced.
  static void progressChanged() {
    if (!signedIn.value) return;
    _pending?.cancel();
    _pending = Timer(const Duration(seconds: 2), _sync);
  }

  /// Reports a non-incremental achievement the moment it's earned.
  static void unlocked(GameAchievement achievement) {
    if (signedIn.value) _call(_unlock(achievement));
  }

  /// Opens the Play Games leaderboard list; false if it couldn't.
  static Future<bool> showLeaderboards() => _show(() => pgs.Leaderboards.showLeaderboards());

  /// Opens the Play Games achievement list; false if it couldn't.
  static Future<bool> showAchievements() => _show(() => pgs.Achievements.showAchievements());

  static Future<bool> _show(Future<Object?> Function() open) async {
    if (!available) return false;
    try {
      if (!signedIn.value) {
        await pgs.GameAuth.signIn().timeout(_timeout);
        signedIn.value = true;
        progressChanged();
      }
      await open().timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _sync() => _syncing ??= () async {
    try {
      await _syncCloud();
      await _submitAll();
    } finally {
      _syncing = null;
    }
  }();

  /// Merges the cloud copy into this device and writes the result back.
  /// Never writes unless the cloud copy was read (or there is none), so a
  /// copy that merely failed to load is never overwritten.
  static Future<void> _syncCloud() async {
    try {
      final saves = await pgs.SaveGame.getSavedGames(forceRefresh: true, ignoreImages: true).timeout(_timeout);
      if (saves == null) return;
      Map<String, dynamic>? cloud;
      if (saves.any((s) => s.name == _saveName)) {
        cloud = CloudProgress.decode(await pgs.SaveGame.loadGame(name: _saveName).timeout(_timeout));
        if (cloud == null) return;
      }
      final prefs = await SharedPreferences.getInstance();
      final local = CloudProgress.export(prefs);
      final merged = cloud == null ? local : CloudProgress.merge(local, cloud);
      if (cloud != null && jsonEncode(merged) != jsonEncode(local)) {
        await CloudProgress.apply(prefs, merged);
      }
      if (cloud == null || jsonEncode(merged) != jsonEncode(cloud)) {
        await pgs.SaveGame.saveGame(
          data: jsonEncode(merged),
          name: _saveName,
          description: 'Khủng long đã ấp: ${PlayerStats.totalHatched}',
        ).timeout(_timeout);
      }
    } catch (_) {}
  }

  /// Scores and achievements from this device's records. Play Games keeps
  /// the best score and ignores repeats, so sending everything is safe.
  static Future<void> _submitAll() async {
    final bests = <GameMode, int>{};
    for (final mode in GameMode.values) {
      for (final difficulty in Difficulty.values) {
        final score = await SaveService.getHighScore(difficulty, mode);
        if (score > (bests[mode] ?? 0)) bests[mode] = score;
      }
    }
    await Future.wait([
      for (final MapEntry(key: mode, value: best) in bests.entries) _submit(_scoreBoards[mode] ?? '', best),
      _submit(_hatchBoard, PlayerStats.totalHatched),
      for (final achievement in GameAchievement.values)
        if (achievement.incremental)
          _setSteps(achievement, PlayerStats.progressOf(achievement))
        else if (PlayerStats.unlocked.contains(achievement))
          _unlock(achievement),
    ]);
  }

  static Future<void> _submit(String board, int value) async {
    if (board.isEmpty || value <= 0) return;
    await _call(pgs.Leaderboards.submitScore(score: pgs.Score(androidLeaderboardID: board, value: value)));
  }

  static Future<void> _unlock(GameAchievement achievement) async {
    final id = _achievementIds[achievement] ?? '';
    if (id.isEmpty) return;
    await _call(pgs.Achievements.unlock(achievement: pgs.Achievement(androidID: id)));
  }

  static Future<void> _setSteps(GameAchievement achievement, int steps) async {
    final id = _achievementIds[achievement] ?? '';
    if (id.isEmpty || steps <= 0) return;
    await _call(pgs.Achievements.setSteps(achievement: pgs.Achievement(androidID: id, steps: steps)));
  }

  static Future<void> _call(Future<Object?> call) async {
    try {
      await call.timeout(_timeout);
    } catch (_) {}
  }
}
