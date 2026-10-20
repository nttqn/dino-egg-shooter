import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dino_species.dart';

/// The player's hatched dinosaurs and chosen companion, persisted across
/// launches. Held in memory as notifiers so the park screen and HUD update
/// live; [init] fills them from disk but isn't awaited before runApp — the
/// defaults (only the starter owned) are a valid state until it finishes.
class DinoCollection {
  /// Owned from the start so the ability system works before any hatch.
  static const DinoSpecies starter = DinoSpecies.trex;

  static const _selectedKey = 'dino_selected';
  static String _hatchKey(DinoSpecies species) => 'dino_hatch_${species.name}';

  static final ValueNotifier<Map<DinoSpecies, int>> hatchCounts =
      ValueNotifier<Map<DinoSpecies, int>>(const {});
  static final ValueNotifier<DinoSpecies> selected = ValueNotifier<DinoSpecies>(starter);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hatchCounts.value = {
        for (final species in DinoSpecies.values) species: prefs.getInt(_hatchKey(species)) ?? 0,
      };
      final savedName = prefs.getString(_selectedKey);
      final saved = DinoSpecies.values.where((s) => s.name == savedName).firstOrNull;
      if (saved != null && isOwned(saved)) selected.value = saved;
    } catch (_) {
      // Unreadable storage just means starting with the default collection.
    }
  }

  static int hatchCount(DinoSpecies species) => hatchCounts.value[species] ?? 0;

  static bool isOwned(DinoSpecies species) => species == starter || hatchCount(species) > 0;

  static int get ownedCount => DinoSpecies.values.where(isOwned).length;

  /// Unowned species hatch first, so the collection fills up steadily;
  /// once everything is owned, any species can hatch again.
  static DinoSpecies pickHatchling(Random random) {
    final unowned = DinoSpecies.values.where((s) => !isOwned(s)).toList();
    final pool = unowned.isNotEmpty ? unowned : DinoSpecies.values;
    return pool[random.nextInt(pool.length)];
  }

  /// Returns true if [species] wasn't owned before this hatch.
  static bool recordHatch(DinoSpecies species) {
    final wasNew = !isOwned(species);
    final count = hatchCount(species) + 1;
    hatchCounts.value = {...hatchCounts.value, species: count};
    _persist((prefs) => prefs.setInt(_hatchKey(species), count));
    return wasNew;
  }

  static void select(DinoSpecies species) {
    if (!isOwned(species)) return;
    selected.value = species;
    _persist((prefs) => prefs.setString(_selectedKey, species.name));
  }

  static void _persist(Future<bool> Function(SharedPreferences prefs) write) {
    SharedPreferences.getInstance().then(write).catchError((_) => false);
  }
}
