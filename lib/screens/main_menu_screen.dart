import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';
import '../services/sound_service.dart';
import '../widgets/menu_background.dart';
import 'difficulty_select_screen.dart';

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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4C41),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        SoundService.playMenuConfirm();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DifficultySelectScreen()),
                        );
                      },
                      child: const Text(
                        'CHƠI',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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

/// `game_title.png` (Android/web) is a widescreen composite (1672x941) that
/// sizes itself from its own intrinsic aspect ratio. The iOS build uses a
/// separate, square (1254x1254) "Pop-a-Saurus" composite — rendered at that
/// same width it would be ~1.8x taller, so it's height-capped via
/// [BoxFit.contain] instead of being left to size off intrinsic width.
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
