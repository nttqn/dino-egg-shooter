import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';
import 'egg_bubble.dart';

/// Placeholder dino character standing beside the launcher, holding the
/// upcoming egg (i.e. mirrors [DinoEggGame.nextColor]) until it's thrown
/// into the launcher on the next shot. Swap for real art later — everything
/// here is procedural canvas drawing, no image assets.
class DinoNpc extends PositionComponent with HasGameReference<DinoEggGame> {
  final double eggDiameter;

  DinoNpc({required super.position, required this.eggDiameter})
    : super(anchor: Anchor.center, size: Vector2.all(eggDiameter * 2.2));

  /// World-space point where the held egg sits — also where a tossed egg
  /// should start its flight from.
  Vector2 get handPosition => position + Vector2(0, size.y * 0.05);

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final body = Paint()..color = const Color(0xFF2E7D32);
    final dark = Paint()..color = const Color(0xFF1B5E20);

    // Tail.
    final tail = Path()
      ..moveTo(w * 0.18, h * 0.55)
      ..lineTo(-w * 0.05, h * 0.66)
      ..lineTo(w * 0.18, h * 0.76)
      ..close();
    canvas.drawPath(tail, body);

    // Body.
    final bodyRect = Rect.fromLTWH(w * 0.15, h * 0.32, w * 0.62, h * 0.56);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.18)), body);

    // Back spikes.
    for (final t in [0.26, 0.4, 0.54]) {
      final p = Offset(w * t, h * 0.34);
      final spike = Path()
        ..moveTo(p.dx - w * 0.045, p.dy)
        ..lineTo(p.dx, p.dy - h * 0.12)
        ..lineTo(p.dx + w * 0.045, p.dy)
        ..close();
      canvas.drawPath(spike, dark);
    }

    // Head + snout.
    final headCenter = Offset(w * 0.74, h * 0.28);
    canvas.drawCircle(headCenter, w * 0.2, body);
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter.translate(w * 0.14, h * 0.06),
        width: w * 0.2,
        height: h * 0.12,
      ),
      body,
    );

    // Eye.
    final eyeCenter = headCenter.translate(w * 0.06, -h * 0.03);
    canvas.drawCircle(eyeCenter, w * 0.045, Paint()..color = Colors.white);
    canvas.drawCircle(eyeCenter.translate(w * 0.012, 0), w * 0.02, Paint()..color = Colors.black);

    // Arm (holding the egg).
    canvas.drawCircle(Offset(w * 0.5, h * 0.58), w * 0.06, dark);

    final color = game.nextColor;
    if (color != null && !game.isTossing) {
      final eggRadius = eggDiameter * 0.42;
      final eggCenter = Offset(w * 0.5, h * 0.63);
      final sprite = eggSpriteFor(color);
      if (sprite != null) {
        sprite.render(
          canvas,
          position: Vector2(eggCenter.dx - eggRadius, eggCenter.dy - eggRadius),
          size: Vector2.all(eggRadius * 2),
        );
      } else {
        canvas.drawCircle(eggCenter, eggRadius, Paint()..color = eggColorPalette[color]!);
      }
    }
  }
}
