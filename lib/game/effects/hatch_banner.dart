import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../../models/dino_species.dart';
import '../dino_egg_game.dart';
import '../entities/dino_portraits.dart';

final _random = Random();

/// Golden sparkle burst where a glowing egg hatched.
class HatchSparkle extends ParticleSystemComponent {
  HatchSparkle({required Vector2 position})
    : super(
        position: position,
        priority: 15,
        particle: Particle.generate(
          count: 16,
          lifespan: 0.7,
          generator: (i) {
            final angle = i / 16 * pi * 2;
            final speed = 80 + _random.nextDouble() * 80;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 120),
              child: ScalingParticle(
                to: 0,
                child: CircleParticle(radius: 4, paint: Paint()..color = const Color(0xFFFFD54F)),
              ),
            );
          },
        ),
      );
}

/// Card announcing which dinosaur just hatched. Pops in at the upper middle
/// of the board, holds, then shrinks away; [startDelay] staggers several
/// hatches that happen at once.
class HatchBanner extends PositionComponent with HasGameReference<DinoEggGame> {
  final DinoSpecies species;
  final bool isNew;
  final double startDelay;

  HatchBanner({required this.species, required this.isNew, this.startDelay = 0})
    : super(anchor: Anchor.center, priority: 21);

  static final _titlePaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
  );
  static final _namePaint = TextPaint(
    style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 17, fontWeight: FontWeight.w900),
  );
  static final _tagPaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(min(game.size.x * 0.86, 320), 96);
    // Above center, so it doesn't collide with a skill's AnnouncementText.
    position = Vector2(game.size.x / 2, game.size.y * 0.3);
    scale = Vector2.zero();

    add(
      SequenceEffect(
        [
          ScaleEffect.to(
            Vector2.all(1.1),
            EffectController(duration: 0.25, startDelay: startDelay, curve: Curves.easeOut),
          ),
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.15)),
          ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 1.8)),
          ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.3, curve: Curves.easeIn)),
        ],
        onComplete: removeFromParent,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final card = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(18));
    canvas.drawRRect(card, Paint()..color = const Color(0xF22B2118));
    canvas.drawRRect(
      card,
      Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    renderDinoPortrait(canvas, species, Rect.fromLTWH(10, 8, 80, 80));

    const textX = 100.0;
    _titlePaint.render(canvas, 'Trứng đã nở!', Vector2(textX, 14));
    _namePaint.render(canvas, species.info.nameVi, Vector2(textX, 36));
    _tagPaint.render(
      canvas,
      isNew ? 'MỚI! Đã vào Vườn khủng long' : '+50 điểm',
      Vector2(textX, 66),
    );
  }
}
