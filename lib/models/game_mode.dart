enum GameMode { normal, endless, timeTrial }

extension GameModeInfo on GameMode {
  String get label => switch (this) {
    GameMode.normal => 'NORMAL',
    GameMode.endless => 'ENDLESS',
    GameMode.timeTrial => 'TIME TRIAL',
  };

  String get description => switch (this) {
    GameMode.normal => 'Chơi qua nhiều màn, càng lên cao hàng trứng đẩy xuống càng nhanh.',
    GameMode.endless => 'Không giới hạn màn chơi, cứ chơi tới khi thua thì thôi.',
    GameMode.timeTrial => 'Ghi điểm cao nhất trong 3 phút trước khi hết giờ.',
  };
}

/// Time Trial's countdown length.
const int kTimeTrialSeconds = 180;
