import 'package:flutter/material.dart';

import '../models/dino_species.dart';

/// A species' portrait art, or a colored initials token while that art
/// doesn't exist yet. [locked] renders it as a dark silhouette.
class DinoPortrait extends StatelessWidget {
  final DinoSpecies species;
  final double size;
  final bool locked;

  const DinoPortrait({super.key, required this.species, required this.size, this.locked = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/${species.portraitFile}',
        fit: BoxFit.contain,
        color: locked ? Colors.black : null,
        colorBlendMode: locked ? BlendMode.srcIn : null,
        errorBuilder: (context, error, stackTrace) => _PlaceholderToken(species: species, size: size, locked: locked),
      ),
    );
  }
}

class _PlaceholderToken extends StatelessWidget {
  final DinoSpecies species;
  final double size;
  final bool locked;

  const _PlaceholderToken({required this.species, required this.size, required this.locked});

  @override
  Widget build(BuildContext context) {
    final info = species.info;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: locked ? Colors.black54 : info.color,
        border: Border.all(color: locked ? Colors.white24 : Colors.white, width: size * 0.05),
      ),
      child: Text(
        locked ? '?' : info.initials,
        style: TextStyle(
          color: locked ? Colors.white38 : Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
