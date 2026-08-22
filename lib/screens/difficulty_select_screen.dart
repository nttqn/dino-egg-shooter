import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../widgets/menu_background.dart';
import 'game_mode_select_screen.dart';

class DifficultySelectScreen extends StatelessWidget {
  const DifficultySelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuBackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('CHỌN ĐỘ KHÓ'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: Difficulty.values
              .map((d) => _DifficultyCard(difficulty: d, accent: d.accentColor))
              .toList(),
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final Difficulty difficulty;
  final Color accent;

  const _DifficultyCard({required this.difficulty, required this.accent});

  @override
  Widget build(BuildContext context) {
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
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GameModeSelectScreen(difficulty: difficulty)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accent,
                child: const Icon(Icons.egg, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      difficulty.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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
