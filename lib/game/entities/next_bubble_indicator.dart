import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';
import '../grid/hex_grid.dart';
import 'egg_bubble.dart';

/// Shows the currently-loaded egg on the launcher itself, plus a smaller
/// preview of the next one off to the side, so the player can plan ahead.
class NextBubbleIndicator extends Component with HasGameReference<DinoEggGame> {
  NextBubbleIndicator() : super(priority: 5);

  @override
  void render(Canvas canvas) {
    final diameter = game.grid.bubbleDiameter;
    final launcherPos = game.launcherPosition;

    final current = game.currentColor;
    if (current != null) {
      _drawEgg(canvas, launcherPos, diameter * 0.8, current);
    }

    final next = game.nextColor;
    if (next != null) {
      final nextPos = Vector2(
        launcherPos.x + diameter * 0.95,
        launcherPos.y - diameter * 0.55,
      );
      _drawEgg(canvas, nextPos, diameter * 0.45, next);
    }
  }

  void _drawEgg(Canvas canvas, Vector2 center, double diameter, EggColor color) {
    final radius = diameter / 2;
    final offset = Offset(center.x, center.y);
    canvas.drawCircle(offset, radius, Paint()..color = eggColorPalette[color]!);
    canvas.drawCircle(
      offset,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
