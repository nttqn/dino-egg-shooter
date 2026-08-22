import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../dino_egg_game.dart';
import 'egg_bubble.dart';

const _dinoSheetPath = 'dino_throw_sheet.png';
const _dinoCols = 5;
const _dinoRows = 2;

/// How long the whole 10-frame throw takes — matched to the flying egg's
/// [MoveToEffect] duration in [DinoEggGame] so the animation and the actual
/// egg landing in the launcher read as one motion.
const double dinoThrowDuration = 0.28;

SpriteAnimation? _throwAnimation;
Vector2? _frameSize;

/// Loads the throw sprite sheet once, ahead of first use. Call from the
/// game's onLoad before [DinoNpc] is created.
///
/// Frames are cut manually (not via [SpriteSheet]) with a small inset on
/// each edge — the source poses weren't laid out on cleanly-separated grid
/// cells, so a plain 1717/5, 916/2 division picks up a sliver of the
/// neighboring pose at some cell edges.
Future<void> loadDinoAnimations(Images imagesCache) async {
  final image = await imagesCache.load(_dinoSheetPath);
  final cellSize = Vector2(image.width / _dinoCols, image.height / _dinoRows);
  final inset = Vector2(cellSize.x * 0.045, cellSize.y * 0.025);
  final frameSize = cellSize - inset * 2;

  final frames = <Sprite>[];
  for (var row = 0; row < _dinoRows; row++) {
    for (var col = 0; col < _dinoCols; col++) {
      final origin = Vector2(col * cellSize.x, row * cellSize.y) + inset;
      frames.add(Sprite(image, srcPosition: origin, srcSize: frameSize));
    }
  }

  _throwAnimation = SpriteAnimation.spriteList(
    frames,
    stepTime: dinoThrowDuration / frames.length,
    loop: false,
  );
  _frameSize = frameSize;
}

/// Dino character standing beside the launcher, holding the upcoming egg
/// (mirroring [DinoEggGame.nextColor]) and playing a throw animation into
/// the launcher on each shot, triggered via [playThrow].
///
/// Composed of two children — the animated body, then the held-egg overlay
/// added after it — rather than drawing the egg in this component's own
/// render(). Flame renders a component's children *after* its own render()
/// call, so drawing the egg there would put it underneath the body sprite
/// added as a child; as a sibling child added later it correctly layers on
/// top instead.
class DinoNpc extends PositionComponent with HasGameReference<DinoEggGame> {
  final double eggDiameter;
  SpriteAnimationComponent? _sprite;

  DinoNpc({required super.position, required this.eggDiameter})
    : super(anchor: Anchor.center, priority: 8);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final frameSize = _frameSize;
    final width = eggDiameter * 2.8;
    final aspect = frameSize != null ? frameSize.y / frameSize.x : 1.33;
    size = Vector2(width, width * aspect);

    final animation = _throwAnimation;
    if (animation != null) {
      final sprite = SpriteAnimationComponent(animation: animation, size: size, playing: false);
      sprite.animationTicker?.onComplete = () {
        sprite.animationTicker?.reset();
        sprite.playing = false;
      };
      _sprite = sprite;
      add(sprite);
    }

    add(_HeldEggOverlay(dino: this, eggDiameter: eggDiameter));
  }

  void playThrow() {
    final sprite = _sprite;
    if (sprite == null) return;
    sprite.animationTicker?.reset();
    sprite.playing = true;
  }

  /// Roughly where the held egg sits in the source art (hands, holding
  /// frame) — an eyeballed fraction of the frame, not exact.
  static const handFraction = Offset(0.485, 0.535);

  /// World-space point where the held egg sits — also where a tossed egg
  /// should start its flight from.
  Vector2 get handPosition =>
      position + Vector2((handFraction.dx - 0.5) * size.x, (handFraction.dy - 0.5) * size.y);

  bool get isHoldingFrame {
    final sprite = _sprite;
    if (sprite == null) return true;
    return !sprite.playing || (sprite.animationTicker?.currentIndex ?? 0) < 3;
  }
}

class _HeldEggOverlay extends Component with HasGameReference<DinoEggGame> {
  final DinoNpc dino;
  final double eggDiameter;

  _HeldEggOverlay({required this.dino, required this.eggDiameter});

  @override
  void render(Canvas canvas) {
    if (!dino.isHoldingFrame) return;
    final color = game.nextColor;
    if (color == null) return;

    final eggRadius = eggDiameter * 0.47;
    final eggCenter = Offset(
      dino.size.x * DinoNpc.handFraction.dx,
      dino.size.y * DinoNpc.handFraction.dy,
    );
    final sprite = eggSpriteFor(color);
    if (sprite != null) {
      sprite.render(
        canvas,
        position: Vector2(eggCenter.dx - eggRadius, eggCenter.dy - eggRadius),
        size: Vector2.all(eggRadius * 2),
      );
    } else {
      canvas.drawCircle(eggCenter, eggRadius, Paint()..color = eggColorPalette[color]!);
    }
  }
}
