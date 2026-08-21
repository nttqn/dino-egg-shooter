import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// The dino "cannon" the player aims. Owns only its visual angle — the
/// game itself decides that angle and fires projectiles.
class Launcher extends PositionComponent {
  /// Direction the barrel points, in radians. Independent from the
  /// component's own [angle] (which is left at 0 — rotation is drawn
  /// manually so the circular base never spins).
  double barrelAngle;
  final double diameter;

  Launcher({
    required this.diameter,
    required Vector2 position,
    this.barrelAngle = -pi / 2,
  }) : super(position: position, anchor: Anchor.center, size: Vector2.all(diameter));

  @override
  void render(Canvas canvas) {
    final radius = diameter / 2;
    final center = Offset(radius, radius);

    canvas.drawCircle(center, radius * 0.85, Paint()..color = const Color(0xFF6D4C41));
    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.12,
    );

    final direction = Offset(cos(barrelAngle), sin(barrelAngle));
    final tip = center + direction * diameter * 0.85;
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFF4E342E)
        ..strokeWidth = radius * 0.4
        ..strokeCap = StrokeCap.round,
    );
  }
}
