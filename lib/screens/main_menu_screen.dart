import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';
import '../services/sound_service.dart';
import '../widgets/menu_background.dart';
import 'difficulty_select_screen.dart';
import 'dino_park_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _banner = AdmobService.createBanner(onLoaded: () => setState(() {}));
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MenuBackgroundScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GameTitleLogo(screenHeight: MediaQuery.of(context).size.height),
                    const SizedBox(height: 48),
                    _MenuButton(
                      label: 'CHƠI',
                      color: const Color(0xFF6D4C41),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DifficultySelectScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      label: 'VƯỜN KHỦNG LONG',
                      color: const Color(0xFF2E7D32),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DinoParkScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_banner != null)
              SizedBox(
                width: _banner!.size.width.toDouble(),
                height: _banner!.size.height.toDouble(),
                child: AdWidget(ad: _banner!),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _MenuButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          SoundService.playMenuConfirm();
          onPressed();
        },
        child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Android/web show the "Dino Egg Shooter" logo at its intrinsic size; the
/// iOS build ("Pop-a-Saurus") uses its own logo, height-capped via
/// [BoxFit.contain] so it can't push the menu buttons off a short screen.
class _GameTitleLogo extends StatelessWidget {
  const _GameTitleLogo({required this.screenHeight});

  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: screenHeight * 0.24,
          child: Image.asset('assets/images/game_title_ios.png', fit: BoxFit.contain),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Image.asset('assets/images/game_title.png'),
    );
  }
}
