import 'package:flutter/material.dart';

import '../services/music_service.dart';
import '../services/sound_service.dart';

/// Music and sound-effect on/off icons, for the main menu's top bar.
class AudioToggleIcons extends StatelessWidget {
  const AudioToggleIcons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: MusicService.enabledNotifier,
          builder: (context, on, _) => _ToggleIcon(
            icon: on ? Icons.music_note : Icons.music_off,
            tooltip: on ? 'Tắt nhạc nền' : 'Bật nhạc nền',
            on: on,
            onPressed: () => MusicService.setEnabled(!on),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.enabledNotifier,
          builder: (context, on, _) => _ToggleIcon(
            icon: on ? Icons.volume_up : Icons.volume_off,
            tooltip: on ? 'Tắt âm thanh' : 'Bật âm thanh',
            on: on,
            onPressed: () {
              SoundService.setEnabled(!on);
              if (!on) SoundService.playMenuConfirm();
            },
          ),
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool on;
  final VoidCallback onPressed;

  const _ToggleIcon({required this.icon, required this.tooltip, required this.on, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(backgroundColor: Colors.black38),
        icon: Icon(icon, color: on ? Colors.white : Colors.white38, size: 28),
      ),
    );
  }
}

/// Music and sound-effect switches, for the pause menu.
class AudioToggleSwitches extends StatelessWidget {
  const AudioToggleSwitches({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: MusicService.enabledNotifier,
          builder: (context, on, _) => _SwitchRow(
            icon: on ? Icons.music_note : Icons.music_off,
            label: 'Nhạc nền',
            value: on,
            onChanged: MusicService.setEnabled,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.enabledNotifier,
          builder: (context, on, _) => _SwitchRow(
            icon: on ? Icons.volume_up : Icons.volume_off,
            label: 'Âm thanh',
            value: on,
            onChanged: SoundService.setEnabled,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
