import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';
import 'egg_bubble.dart';

/// Shows the currently-loaded egg sitting on the launcher. Hidden while the
/// dino NPC's toss animation is in flight, since that egg takes over this
/// spot visually until it lands. The upcoming egg is shown by [DinoNpc]
/// instead, in its hands.
class LoadedEggIndicator extends Component with HasGameReference<DinoEggGame> {
  LoadedEggIndicator() : super(priority: 5);

  double _time = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (game.isTossing) return;

    final current = game.currentColor;
    if (current == null) return;

    final diameter = game.grid.bubbleDiameter * 0.8;
    final center = game.launcherPosition;
    final offset = Offset(center.x, center.y);
    final radius = diameter / 2;
    final sprite = eggSpriteFor(current);
    if (sprite != null) {
      sprite.render(
        canvas,
        position: Vector2(center.x - radius, center.y - radius),
        size: Vector2.all(diameter),
      );
    } else {
      canvas.drawCircle(offset, radius, Paint()..color = eggColorPalette[current]!);
      canvas.drawCircle(
        offset,
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final armed = game.armedModifier;
    if (armed != null) paintModifierRing(canvas, offset, radius, armed, _time);
  }
}
