import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

class SoundService {
  static const _shoot = 'sfx_bubble_stick.wav';
  static const _stick = 'sfx_bubble_paint.wav';
  static const _pop = 'sfx_bubble_explosive.wav';
  static const _menuBack = 'sfx_menu_back.wav';
  static const _menuConfirm = 'sfx_menu_confirm.wav';

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([_shoot, _stick, _pop, _menuBack, _menuConfirm]);
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }

  /// The egg leaving the launcher.
  static void playShoot() => _play(_shoot);

  /// The flying egg attaching to the pile.
  static void playStick() => _play(_stick);

  /// Eggs popping (a match, or bubbles falling loose).
  static void playPop() => _play(_pop);

  /// Pause button and back navigation.
  static void playMenuBack() => _play(_menuBack);

  /// Any menu button tap.
  static void playMenuConfirm() => _play(_menuConfirm);

  static void _play(String file) {
    // Fire-and-forget: a sound failing to play should never interrupt
    // gameplay or navigation.
    unawaited(_playSafely(file));
  }

  static Future<void> _playSafely(String file) async {
    try {
      await FlameAudio.play(file);
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }
}
