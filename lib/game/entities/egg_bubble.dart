import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../grid/hex_grid.dart';

/// Fallback fill color, used only if a sprite hasn't finished loading yet.
const Map<EggColor, Color> eggColorPalette = {
  EggColor.red: Color(0xFFE53935),
  EggColor.blue: Color(0xFF1E88E5),
  EggColor.green: Color(0xFF43A047),
  EggColor.yellow: Color(0xFFFDD835),
  EggColor.purple: Color(0xFF8E24AA),
};

String eggAssetPath(EggColor color) => switch (color) {
  EggColor.red => 'egg_red.png',
  EggColor.blue => 'egg_blue.png',
  EggColor.green => 'egg_green.png',
  EggColor.yellow => 'egg_yellow.png',
  EggColor.purple => 'egg_purple.png',
};

final Map<EggColor, Sprite> _eggSprites = {};

/// Loads every egg sprite once, ahead of first use. Call from the game's
/// onLoad before any [EggBubble] is created.
Future<void> loadEggSprites(Images imagesCache) async {
  for (final color in EggColor.values) {
    final image = await imagesCache.load(eggAssetPath(color));
    _eggSprites[color] = Sprite(image);
  }
}

/// The loaded sprite for [color], if [loadEggSprites] has completed.
Sprite? eggSpriteFor(EggColor color) => _eggSprites[color];

/// Renders a single egg bubble at a fixed position. Grid bubbles reposition
/// via [position] when placed/removed; the launcher's projectile is a
/// separate moving instance of this same component.
class EggBubble extends CircleComponent {
  EggColor color;

  EggBubble({required this.color, required double diameter, super.position})
    : super(
        radius: diameter / 2,
        anchor: Anchor.center,
        paint: Paint()..color = eggColorPalette[color]!,
      );

  @override
  void render(Canvas canvas) {
    final sprite = _eggSprites[color];
    if (sprite == null) {
      super.render(canvas);
      return;
    }
    sprite.render(canvas, size: Vector2.all(radius * 2));
  }
}
