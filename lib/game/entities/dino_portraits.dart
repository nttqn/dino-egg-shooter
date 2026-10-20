import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/dino_species.dart';

final Map<DinoSpecies, Sprite> _portraits = {};

/// Loads whichever species portraits exist. A missing file isn't an error —
/// [renderDinoPortrait] draws a placeholder token for it instead. Checked
/// against the asset manifest first: Flame's image cache reports a failed
/// load as an uncaught async error even when the caller catches it.
Future<void> loadDinoPortraits(Images imagesCache) async {
  final Set<String> bundled;
  try {
    bundled = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets().toSet();
  } catch (_) {
    return;
  }
  for (final species in DinoSpecies.values) {
    if (_portraits.containsKey(species)) continue;
    if (!bundled.contains('assets/images/${species.portraitFile}')) continue;
    try {
      _portraits[species] = Sprite(await imagesCache.load(species.portraitFile));
    } catch (_) {}
  }
}

/// Draws [species]' portrait fitted into [rect], keeping its aspect ratio.
void renderDinoPortrait(Canvas canvas, DinoSpecies species, Rect rect) {
  final sprite = _portraits[species];
  if (sprite != null) {
    final src = sprite.srcSize;
    final scale = (rect.width / src.x) < (rect.height / src.y) ? rect.width / src.x : rect.height / src.y;
    final size = Vector2(src.x * scale, src.y * scale);
    sprite.render(
      canvas,
      position: Vector2(rect.center.dx - size.x / 2, rect.bottom - size.y),
      size: size,
    );
    return;
  }

  final info = species.info;
  final radius = rect.shortestSide * 0.36;
  final center = rect.center;
  canvas.drawCircle(center, radius, Paint()..color = info.color);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1,
  );
  final textPaint = TextPaint(
    style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.w900),
  );
  textPaint.render(canvas, info.initials, Vector2(center.dx, center.dy), anchor: Anchor.center);
}
