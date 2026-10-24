import 'package:flutter/material.dart';

import '../services/play_games.dart';
import '../services/sound_service.dart';

/// Leaderboard and achievement buttons for the main menu's top bar. Hidden
/// where Play Games isn't available (iOS, web).
class PlayGamesButtons extends StatelessWidget {
  const PlayGamesButtons({super.key});

  Future<void> _open(BuildContext context, Future<bool> Function() open) async {
    SoundService.playMenuConfirm();
    final messenger = ScaffoldMessenger.of(context);
    if (await open()) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Chưa kết nối được Google Play Games. Hãy kiểm tra mạng và tài khoản Google.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!PlayGames.available) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(context, Icons.leaderboard, 'Bảng xếp hạng', PlayGames.showLeaderboards),
        _button(context, Icons.emoji_events, 'Thành tựu', PlayGames.showAchievements),
      ],
    );
  }

  Widget _button(BuildContext context, IconData icon, String tooltip, Future<bool> Function() open) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: () => _open(context, open),
        style: IconButton.styleFrom(backgroundColor: Colors.black38),
        icon: Icon(icon, color: const Color(0xFFFFD54F), size: 28),
      ),
    );
  }
}
