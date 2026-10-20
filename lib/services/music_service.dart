import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looping background music — one track for the menus, one for play. Both
/// are synthesised by `tool/gen_music.js`; regenerate from there rather
/// than editing the WAVs.
///
/// Has its own on/off switch, independent of [SoundService]'s, so a player
/// can mute music and sound effects separately.
class MusicService {
  static const _menuTrack = 'bgm_menu.wav';
  static const _gameTrack = 'bgm_game.wav';
  static const _volume = 0.4;
  static const _enabledPrefKey = 'music_enabled';

  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  static String? _wanted;
  static String? _playing;
  static bool _initialized = false;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledPrefKey) ?? true;
    } catch (_) {}
    try {
      // Passed here explicitly (not just via SoundService's global default):
      // the two services init unawaited in no guaranteed order, and bgm
      // otherwise keeps its own focus-taking default, which lets every
      // sound effect cut the music out on Android.
      await FlameAudio.bgm.initialize(
        audioContext: AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _initialized = true;
      // The menu usually asks for its track before init finishes.
      final pending = _wanted;
      if (pending != null) _play(pending);
    } catch (_) {
      // No music this session; the game stays fully playable in silence.
    }
  }

  static void playMenu() => _play(_menuTrack);

  static void playGame() => _play(_gameTrack);

  static void _play(String track) {
    _wanted = track;
    if (!_initialized || !enabledNotifier.value || _playing == track) return;
    _playing = track;
    FlameAudio.bgm.play(track, volume: _volume).catchError((_) {});
  }

  static Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    if (_initialized) {
      if (value) {
        final wanted = _wanted;
        if (wanted != null) _play(wanted);
      } else {
        _playing = null;
        FlameAudio.bgm.stop().catchError((_) {});
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPrefKey, value);
    } catch (_) {}
  }
}
