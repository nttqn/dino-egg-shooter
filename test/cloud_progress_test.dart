import 'package:dino_egg_shooter/models/dino_species.dart';
import 'package:dino_egg_shooter/models/game_achievement.dart';
import 'package:dino_egg_shooter/services/cloud_progress.dart';
import 'package:dino_egg_shooter/services/dino_collection.dart';
import 'package:dino_egg_shooter/services/player_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    DinoCollection.hatchCounts.value = const {};
    DinoCollection.selected.value = DinoCollection.starter;
    PlayerStats.eggsPopped = 0;
    PlayerStats.skillsUsed = 0;
    PlayerStats.unlocked.clear();
  });

  test('merge keeps the larger counter and the union of achievements', () {
    final local = {
      'v': 1,
      'counters': {'dino_hatch_trex': 3, 'high_score_easy_normal': 900, 'stat_eggs_popped': 50},
      'unlocked': ['firstHatch'],
      'selected': 'stegosaurus',
    };
    final cloud = {
      'v': 1,
      'counters': {'dino_hatch_trex': 1, 'dino_hatch_pteranodon': 2, 'high_score_easy_normal': 1500},
      'unlocked': ['level5', 'firstHatch'],
      'selected': 'trex',
    };

    final merged = CloudProgress.merge(local, cloud);

    expect(merged['counters'], {
      'dino_hatch_trex': 3,
      'dino_hatch_pteranodon': 2,
      'high_score_easy_normal': 1500,
      'stat_eggs_popped': 50,
    });
    expect(merged['unlocked'], ['firstHatch', 'level5']);
    expect(merged['selected'], 'stegosaurus');
  });

  test('decode rejects garbage and snapshots from a newer version', () {
    expect(CloudProgress.decode(null), isNull);
    expect(CloudProgress.decode('not json'), isNull);
    expect(CloudProgress.decode('{"v": 99}'), isNull);
    expect(CloudProgress.decode('{"v": 1, "counters": {}}'), isNotNull);
  });

  test('export then apply round-trips into the in-memory collection and stats', () async {
    SharedPreferences.setMockInitialValues({
      'dino_hatch_triceratops': 2,
      'stat_eggs_popped': 120,
      'achievements_unlocked': ['firstHatch'],
      'sound_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final snapshot = CloudProgress.export(prefs);
    expect(snapshot['counters'], {'dino_hatch_triceratops': 2, 'stat_eggs_popped': 120});

    SharedPreferences.setMockInitialValues({});
    final fresh = await SharedPreferences.getInstance();
    await CloudProgress.apply(fresh, snapshot);

    expect(DinoCollection.isOwned(DinoSpecies.triceratops), isTrue);
    expect(PlayerStats.eggsPopped, 120);
    expect(PlayerStats.unlocked, {GameAchievement.firstHatch});
  });

  test('apply never lowers counters a round in progress has not flushed yet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    PlayerStats.eggsPopped = 500;
    await CloudProgress.apply(prefs, {
      'v': 1,
      'counters': {'stat_eggs_popped': 200},
      'unlocked': <String>[],
    });
    expect(PlayerStats.eggsPopped, 500);
  });

  test('incremental progress is capped at the achievement step count', () {
    PlayerStats.eggsPopped = 5000;
    expect(PlayerStats.progressOf(GameAchievement.pop1000), 1000);
    PlayerStats.skillsUsed = 7;
    expect(PlayerStats.progressOf(GameAchievement.skill50), 7);
  });
}
