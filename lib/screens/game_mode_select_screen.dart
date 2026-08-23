import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/game_mode.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../widgets/menu_background.dart';
import 'game_screen.dart';

class GameModeSelectScreen extends StatelessWidget {
  final Difficulty difficulty;

  const GameModeSelectScreen({super.key, required this.difficulty});

  static const _icons = {
    GameMode.normal: Icons.stairs,
    GameMode.endless: Icons.all_inclusive,
    GameMode.timeTrial: Icons.timer,
  };

  @override
  Widget build(BuildContext context) {
    return MenuBackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('CHỌN CHẾ ĐỘ'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: GameMode.values.map((mode) => _ModeCard(mode: mode, difficulty: difficulty)).toList(),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GameMode mode;
  final Difficulty difficulty;

  const _ModeCard({required this.mode, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final accent = difficulty.accentColor;
    return Card(
      color: const Color(0xFF2B2118),
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          SoundService.playMenuConfirm();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GameScreen(difficulty: difficulty, mode: mode)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accent,
                child: Icon(
                  GameModeSelectScreen._icons[mode],
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<int>(
                      future: SaveService.getHighScore(difficulty, mode),
                      builder: (context, snapshot) {
                        final highScore = snapshot.data;
                        if (highScore == null || highScore == 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'Điểm cao nhất: $highScore',
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
