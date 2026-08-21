import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';

void main() {
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
