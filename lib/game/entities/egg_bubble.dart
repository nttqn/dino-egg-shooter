import 'dart:math';

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

/// A companion skill applied to a single shot.
enum ShotModifier { pierce, bomb, rainbow }

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

/// Golden pulsing halo marking an egg that hatches a dinosaur when popped.
void paintSpecialHalo(Canvas canvas, Offset center, double radius, double time) {
  final pulse = 0.5 + 0.5 * sin(time * 5);
  canvas.drawCircle(
    center,
    radius * 1.05,
    Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.35 + 0.35 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, radius * 0.35),
  );
  canvas.drawCircle(
    center,
    radius * 1.0,
    Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * (0.16 + 0.06 * pulse),
  );

  final sparkle = center + Offset(radius * 0.55, -radius * 0.6);
  final s = radius * (0.22 + 0.08 * pulse);
  final path = Path()
    ..moveTo(sparkle.dx, sparkle.dy - s)
    ..lineTo(sparkle.dx + s * 0.3, sparkle.dy - s * 0.3)
    ..lineTo(sparkle.dx + s, sparkle.dy)
    ..lineTo(sparkle.dx + s * 0.3, sparkle.dy + s * 0.3)
    ..lineTo(sparkle.dx, sparkle.dy + s)
    ..lineTo(sparkle.dx - s * 0.3, sparkle.dy + s * 0.3)
    ..lineTo(sparkle.dx - s, sparkle.dy)
    ..lineTo(sparkle.dx - s * 0.3, sparkle.dy - s * 0.3)
    ..close();
  canvas.drawPath(path, Paint()..color = Colors.white);
}

/// Ring around an egg armed with a companion skill.
void paintModifierRing(Canvas canvas, Offset center, double radius, ShotModifier modifier, double time) {
  final pulse = 0.5 + 0.5 * sin(time * 8);
  final ringRadius = radius * (1.12 + 0.06 * pulse);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = radius * 0.2;
  switch (modifier) {
    case ShotModifier.pierce:
      paint.color = const Color(0xFF4FC3F7);
    case ShotModifier.bomb:
      paint.color = const Color(0xFFFF5722).withValues(alpha: 0.7 + 0.3 * pulse);
    case ShotModifier.rainbow:
      paint.shader = SweepGradient(
        transform: GradientRotation(time * 3),
        colors: const [
          Color(0xFFE53935),
          Color(0xFFFDD835),
          Color(0xFF43A047),
          Color(0xFF1E88E5),
          Color(0xFF8E24AA),
          Color(0xFFE53935),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius));
  }
  canvas.drawCircle(center, ringRadius, paint);
}

/// Renders a single egg bubble at a fixed position. Grid bubbles reposition
/// via [position] when placed/removed; the launcher's projectile is a
/// separate moving instance of this same component.
class EggBubble extends CircleComponent {
  EggColor color;
  final bool special;
  final ShotModifier? modifier;
  double _time = 0;

  EggBubble({
    required this.color,
    required double diameter,
    super.position,
    this.special = false,
    this.modifier,
  }) : super(
         radius: diameter / 2,
         anchor: Anchor.center,
         paint: Paint()..color = eggColorPalette[color]!,
       );

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final sprite = _eggSprites[color];
    if (sprite == null) {
      super.render(canvas);
    } else {
      sprite.render(canvas, size: Vector2.all(radius * 2));
    }
    if (special) paintSpecialHalo(canvas, center, radius, _time);
    final mod = modifier;
    if (mod != null) paintModifierRing(canvas, center, radius, mod, _time);
  }
}
