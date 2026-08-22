import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';

/// Big bold banner text ("START", "LEVEL 2", ...) that pops into the
/// center of the screen, holds, then shrinks away — 2 seconds total —
/// shown at the start of a round and, in Normal mode, at each new level.
class AnnouncementText extends TextComponent with HasGameReference<DinoEggGame> {
  AnnouncementText(String text)
    : super(
        text: text,
        anchor: Anchor.center,
        priority: 20,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
        ),
      );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position = game.size / 2;
    scale = Vector2.zero();

    add(
      SequenceEffect(
        [
          ScaleEffect.to(Vector2.all(1.15), EffectController(duration: 0.3, curve: Curves.easeOut)),
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2, curve: Curves.easeIn)),
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 1.0)),
          ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.5, curve: Curves.easeIn)),
        ],
        onComplete: removeFromParent,
      ),
    );
  }
}
