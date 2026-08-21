import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/dino_egg_game.dart';
import '../models/difficulty.dart';
import '../services/save_service.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;

  const GameScreen({super.key, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DinoEggGame _game = DinoEggGame(difficulty: widget.difficulty);

  void _togglePause() {
    if (_game.paused) {
      _game.overlays.remove('paused');
      _game.resumeEngine();
    } else {
      _game.pauseEngine();
      _game.overlays.add('paused');
    }
    setState(() {});
  }

  void _backToMenu() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'gameOver': (context, game) => _RoundEndOverlay(
                title: 'GAME OVER',
                color: const Color(0xFFC62828),
                score: (game as DinoEggGame).score,
                difficulty: widget.difficulty,
                onRestart: _game.restart,
                onMenu: _backToMenu,
              ),
              'youWin': (context, game) => _RoundEndOverlay(
                title: 'BẠN THẮNG!',
                color: const Color(0xFF2E7D32),
                score: (game as DinoEggGame).score,
                difficulty: widget.difficulty,
                onRestart: _game.restart,
                onMenu: _backToMenu,
              ),
              'paused': (context, game) => _PausedOverlay(
                onResume: _togglePause,
                onMenu: _backToMenu,
              ),
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.pause_circle_filled, color: Colors.white70, size: 32),
                onPressed: _togglePause,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundEndOverlay extends StatefulWidget {
  final String title;
  final Color color;
  final int score;
  final Difficulty difficulty;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  const _RoundEndOverlay({
    required this.title,
    required this.color,
    required this.score,
    required this.difficulty,
    required this.onRestart,
    required this.onMenu,
  });

  @override
  State<_RoundEndOverlay> createState() => _RoundEndOverlayState();
}

class _RoundEndOverlayState extends State<_RoundEndOverlay> {
  late final Future<bool> _isNewHighScore = SaveService.submitScore(
    widget.difficulty,
    widget.score,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2118),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.color, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: widget.color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Điểm: ${widget.score}',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            FutureBuilder<bool>(
              future: _isNewHighScore,
              builder: (context, snapshot) {
                if (snapshot.data != true) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Kỷ lục mới!',
                    style: TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(onPressed: widget.onRestart, child: const Text('Chơi lại')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: widget.onMenu, child: const Text('Về menu')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onMenu;

  const _PausedOverlay({required this.onResume, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2118),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TẠM DỪNG',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(onPressed: onResume, child: const Text('Tiếp tục')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: onMenu, child: const Text('Về menu')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
