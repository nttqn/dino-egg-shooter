import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../entities/egg_bubble.dart';
import '../grid/hex_grid.dart';

final _random = Random();

/// Fragments are cut from a 3x3 grid of the egg's own sprite, so the burst
/// looks like the actual egg shattering rather than generic colored dots.
const _gridSize = 3;

/// A burst of shattered fragments cut from the egg's own sprite (color
/// falls back to a flat circle if the sprite hasn't loaded), fired once at
/// [position] and self-removing when it finishes.
class PopEffect extends ParticleSystemComponent {
  PopEffect({required Vector2 position, required EggColor color, required double diameter})
    : super(position: position, particle: _buildParticle(color, diameter));

  static Particle _buildParticle(EggColor color, double diameter) {
    final sprite = eggSpriteFor(color);
    final fragmentWorldSize = diameter / _gridSize;
    final cellSize = sprite != null ? sprite.srcSize / _gridSize.toDouble() : null;

    return Particle.generate(
      count: _gridSize * _gridSize,
      lifespan: 0.5,
      generator: (i) {
        final col = i % _gridSize;
        final row = i ~/ _gridSize;

        // Fragments fly outward from the egg's center, roughly matching
        // their own position within the grid (top-left piece flies
        // up-left, etc.) — the center piece has no natural direction, so
        // just send it upward.
        var direction = Vector2((col - 1).toDouble(), (row - 1).toDouble());
        if (direction.length2 < 1e-6) direction = Vector2(0, -1);
        direction.normalize();

        final speed = 90 + _random.nextDouble() * 90;
        final velocity =
            direction * speed + Vector2((_random.nextDouble() - 0.5) * 40, -20);

        final Particle fragment;
        if (sprite != null && cellSize != null) {
          final fragmentSprite = Sprite(
            sprite.image,
            srcPosition: sprite.srcPosition + Vector2(col * cellSize.x, row * cellSize.y),
            srcSize: cellSize,
          );
          fragment = SpriteParticle(sprite: fragmentSprite, size: Vector2.all(fragmentWorldSize));
        } else {
          fragment = CircleParticle(
            radius: fragmentWorldSize / 2,
            paint: Paint()..color = eggColorPalette[color]!,
          );
        }

        return AcceleratedParticle(
          speed: velocity,
          acceleration: Vector2(0, 260),
          child: RotatingParticle(
            from: 0,
            to: (_random.nextDouble() - 0.5) * pi * 2,
            child: ScalingParticle(to: 0, child: fragment),
          ),
        );
      },
    );
  }
}
