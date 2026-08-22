import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../entities/egg_bubble.dart';
import '../grid/hex_grid.dart';

final _random = Random();

/// A small radiating burst of shard particles in [color], fired once at
/// [position] and self-removing when it finishes.
class PopEffect extends ParticleSystemComponent {
  PopEffect({required Vector2 position, required EggColor color})
    : super(
        position: position,
        particle: Particle.generate(
          count: 8,
          lifespan: 0.4,
          generator: (i) {
            final angle = _random.nextDouble() * pi * 2;
            final speed = 80 + _random.nextDouble() * 80;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 260),
              child: CircleParticle(
                radius: 3 + _random.nextDouble() * 3,
                paint: Paint()..color = eggColorPalette[color]!,
              ),
            );
          },
        ),
      );
}
