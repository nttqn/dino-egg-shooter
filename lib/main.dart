import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';
import 'services/admob_service.dart';
import 'services/dino_collection.dart';
import 'services/music_service.dart';
import 'services/play_games.dart';
import 'services/player_stats.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdmobService.init();
  SoundService.preload();
  MusicService.init();
  DinoCollection.init();
  PlayerStats.load().then((_) => PlayGames.start());
  runApp(const DinoEggShooterApp());
}

class DinoEggShooterApp extends StatelessWidget {
  const DinoEggShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainMenuScreen(),
    );
  }
}
