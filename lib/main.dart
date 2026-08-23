import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';
import 'services/admob_service.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdmobService.init();
  SoundService.preload();
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
