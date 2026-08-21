import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';

/// Draws the dashed trajectory preview from the launcher to the first
/// obstruction, bouncing off the side walls like the reference game.
class AimLine extends Component with HasGameReference<DinoEggGame> {
  AimLine() : super(priority: 10);

  @override
  void render(Canvas canvas) {
    final points = game.computeAimPath();
    if (points.length < 2) return;

    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i].toOffset(), points[i + 1].toOffset(), paint);
    }
  }
}
