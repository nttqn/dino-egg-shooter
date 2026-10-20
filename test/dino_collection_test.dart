import 'dart:math';

import 'package:dino_egg_shooter/models/dino_species.dart';
import 'package:dino_egg_shooter/services/dino_collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DinoCollection.hatchCounts.value = const {};
    DinoCollection.selected.value = DinoCollection.starter;
    await DinoCollection.init();
  });

  test('only the starter is owned at first', () {
    expect(DinoCollection.ownedCount, 1);
    expect(DinoCollection.isOwned(DinoCollection.starter), isTrue);
  });

  test('hatching prefers species not yet owned', () {
    final random = Random(1);
    final seen = <DinoSpecies>{};
    for (var i = 0; i < DinoSpecies.values.length - 1; i++) {
      final species = DinoCollection.pickHatchling(random);
      expect(DinoCollection.isOwned(species), isFalse);
      expect(DinoCollection.recordHatch(species), isTrue);
      seen.add(species);
    }
    expect(DinoCollection.ownedCount, DinoSpecies.values.length);
    expect(seen.length, DinoSpecies.values.length - 1);
  });

  test('a repeat hatch is not new and bumps the count', () {
    expect(DinoCollection.recordHatch(DinoSpecies.stegosaurus), isTrue);
    expect(DinoCollection.recordHatch(DinoSpecies.stegosaurus), isFalse);
    expect(DinoCollection.hatchCount(DinoSpecies.stegosaurus), 2);
  });

  test('only owned species can be selected, and selection persists', () async {
    DinoCollection.select(DinoSpecies.pteranodon);
    expect(DinoCollection.selected.value, DinoCollection.starter);

    DinoCollection.recordHatch(DinoSpecies.pteranodon);
    DinoCollection.select(DinoSpecies.pteranodon);
    expect(DinoCollection.selected.value, DinoSpecies.pteranodon);

    await Future<void>.delayed(Duration.zero);
    DinoCollection.selected.value = DinoCollection.starter;
    await DinoCollection.init();
    expect(DinoCollection.selected.value, DinoSpecies.pteranodon);
  });
}
