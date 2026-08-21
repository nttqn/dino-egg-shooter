import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../grid/hex_grid.dart';

/// Visual placeholder palette until real egg sprites are added.
const Map<EggColor, Color> eggColorPalette = {
  EggColor.red: Color(0xFFE53935),
  EggColor.blue: Color(0xFF1E88E5),
  EggColor.green: Color(0xFF43A047),
  EggColor.yellow: Color(0xFFFDD835),
  EggColor.purple: Color(0xFF8E24AA),
};

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
    super.render(canvas);
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(radius, radius), radius, outline);
  }
}
