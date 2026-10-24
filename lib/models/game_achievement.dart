/// Achievements, tracked locally and mirrored to Google Play Games.
/// Incremental ones ([steps] > 0) are derived from lifetime counters in
/// [PlayerStats] rather than unlocked directly.
enum GameAchievement {
  firstHatch,
  fullPark,
  hatch25,
  firstSkill,
  skill50,
  pop1000,
  bigCombo,
  level5,
  level10,
  timeTrial3000,
}

extension GameAchievementInfo on GameAchievement {
  /// Step count for achievements created as incremental in Play Console.
  int get steps => switch (this) {
    GameAchievement.hatch25 => 25,
    GameAchievement.skill50 => 50,
    GameAchievement.pop1000 => 1000,
    _ => 0,
  };

  bool get incremental => steps > 0;
}

/// Eggs popped by a single shot needed for [GameAchievement.bigCombo].
const int kBigComboSize = 15;
const int kTimeTrialTargetScore = 3000;
