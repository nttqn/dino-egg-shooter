enum Difficulty { easy, normal, hard }

extension DifficultyTuning on Difficulty {
  String get label => switch (this) {
    Difficulty.easy => 'EASY',
    Difficulty.normal => 'NORMAL',
    Difficulty.hard => 'HARD',
  };

  String get description => switch (this) {
    Difficulty.easy => 'Bắt đầu ở đây với độ khó cơ bản!',
    Difficulty.normal => 'Khi bạn đã quen tay! Khó hơn, nhưng ghi điểm cao hơn.',
    Difficulty.hard => 'Cực kỳ khó, dành cho người chơi thành thạo.',
  };

  /// Fewer colors on easy makes matches easier to find. Capped at the 5
  /// colors EggColor defines.
  int get colorCount => switch (this) {
    Difficulty.easy => 3,
    Difficulty.normal => 4,
    Difficulty.hard => 5,
  };

  /// A new row is pushed down every this many shots — lower is harder.
  int get shotsPerPushDown => switch (this) {
    Difficulty.easy => 8,
    Difficulty.normal => 6,
    Difficulty.hard => 4,
  };
}
