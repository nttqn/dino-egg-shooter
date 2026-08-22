import 'dart:math';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../dino_egg_game.dart';

const _backgroundCount = 4;

final List<Sprite> _backgroundSprites = [];

/// Loads all 4 background variants once, ahead of first use. Call from the
/// game's onLoad before [BackgroundLayer] is created.
Future<void> loadBackgrounds(Images imagesCache) async {
  _backgroundSprites.clear();
  for (var i = 1; i <= _backgroundCount; i++) {
    final image = await imagesCache.load('background_$i.png');
    _backgroundSprites.add(Sprite(image));
  }
}

/// Full-canvas backdrop, lowest priority so every other component draws
/// over it. [randomize] swaps in a different one of the 4 variants —
/// called each time a fresh board is populated (new round or, in Normal
/// mode, a new level), so the setting changes as the player progresses.
class BackgroundLayer extends SpriteComponent with HasGameReference<DinoEggGame> {
  BackgroundLayer() : super(priority: -10);

  final _random = Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = game.size.clone();
    randomize();
  }

  void randomize() {
    if (_backgroundSprites.isEmpty) return;
    sprite = _backgroundSprites[_random.nextInt(_backgroundSprites.length)];
  }
}
