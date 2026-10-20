import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../../models/dino_species.dart';
import '../dino_egg_game.dart';
import 'dino_portraits.dart';

/// The player's chosen companion, standing to the right of the launcher
/// (mirroring the egg-throwing dino on the left). Glows while its skill is
/// charged and hops when the skill is used.
class CompanionDino extends PositionComponent with HasGameReference<DinoEggGame> {
  final DinoSpecies species;
  double _time = 0;

  CompanionDino({required this.species, required super.position, required double height})
    : super(size: Vector2.all(height), anchor: Anchor.bottomCenter, priority: 8);

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  void celebrate() {
    add(
      SequenceEffect([
        MoveByEffect(Vector2(0, -size.y * 0.25), EffectController(duration: 0.15, curve: Curves.easeOut)),
        MoveByEffect(Vector2(0, size.y * 0.25), EffectController(duration: 0.2, curve: Curves.bounceOut)),
      ]),
    );
  }

  @override
  void render(Canvas canvas) {
    final bob = sin(_time * 2.5) * size.y * 0.02;
    final rect = Rect.fromLTWH(0, bob, size.x, size.y);

    if (game.energyNotifier.value >= 1) {
      final pulse = 0.5 + 0.5 * sin(_time * 6);
      canvas.drawCircle(
        rect.center,
        size.x * (0.55 + 0.05 * pulse),
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.25 + 0.25 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    renderDinoPortrait(canvas, species, rect);
  }
}
