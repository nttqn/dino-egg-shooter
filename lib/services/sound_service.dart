import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const _shoot = 'sfx_bubble_stick.wav';
  static const _stick = 'sfx_bubble_paint.wav';
  static const _pop = 'sfx_bubble_explosive.wav';
  static const _menuBack = 'sfx_menu_back.wav';
  static const _menuConfirm = 'sfx_menu_confirm.wav';

  static const _enabledPrefKey = 'sound_enabled';

  /// Whether sound effects should play, persisted across launches. A
  /// [ValueNotifier] so the pause menu's toggle can reflect it live.
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  static bool get enabled => enabledNotifier.value;

  /// One small reusable player pool per sound file. `FlameAudio.play()`
  /// spins up a brand-new native AudioPlayer on every call and never
  /// disposes it — fine for a rare sound, but these fire constantly during
  /// play, so that leaks player instances and the audio backend gets
  /// progressively slower/laggier the longer a session runs. Pools reuse a
  /// handful of players instead.
  static final Map<String, AudioPool> _pools = {};

  static Future<void> preload() async {
    await _loadEnabledState();
    try {
      await FlameAudio.audioCache.loadAll([_shoot, _stick, _pop, _menuBack, _menuConfirm]);
      _pools[_shoot] = await FlameAudio.createPool(_shoot, maxPlayers: 3);
      _pools[_stick] = await FlameAudio.createPool(_stick, maxPlayers: 3);
      _pools[_pop] = await FlameAudio.createPool(_pop, maxPlayers: 4);
      _pools[_menuBack] = await FlameAudio.createPool(_menuBack, maxPlayers: 2);
      _pools[_menuConfirm] = await FlameAudio.createPool(_menuConfirm, maxPlayers: 2);
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }

  static Future<void> _loadEnabledState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledPrefKey) ?? true;
    } catch (_) {
      // Fall back to the default (enabled) if prefs aren't available.
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPrefKey, value);
    } catch (_) {
      // Not persisting the choice isn't worth failing over.
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
    if (!enabled) return;
    // Fire-and-forget: a sound failing to play should never interrupt
    // gameplay or navigation.
    unawaited(_playSafely(file));
  }

  static Future<void> _playSafely(String file) async {
    try {
      final pool = _pools[file];
      if (pool != null) {
        await pool.start();
      } else {
        // Pool wasn't ready yet (e.g. preload() hadn't finished) — still
        // play something rather than staying silent.
        await FlameAudio.play(file);
      }
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }
}
