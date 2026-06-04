import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';

void main() {
  final registry = ToyCategoryRegistry.standard();

  test('known toy category counts as toy and is not ignored', () {
    final def = registry.lookup('toy_car');
    expect(def.countsAsToy, isTrue);
    expect(def.isIgnored, isFalse);
    expect(def.minimumConfidence, greaterThan(0));
  });

  test('person is ignored and never counts as toy', () {
    final def = registry.lookup('person');
    expect(def.isIgnored, isTrue);
    expect(def.countsAsToy, isFalse);
  });

  test('not_toy is registered but does not count as a toy', () {
    final def = registry.lookup('not_toy');
    expect(def.countsAsToy, isFalse);
    expect(def.isIgnored, isTrue);
  });

  test('unknown label falls back to the ignored unknown definition', () {
    final def = registry.lookup('spaceship');
    expect(registry.isKnown('spaceship'), isFalse);
    expect(def.label, 'unknown');
    expect(def.countsAsToy, isFalse);
    expect(def.isIgnored, isTrue);
  });

  test('explicitly-ignored categories are present and never count', () {
    // Phase 6.0 registry slimmed down to what the COCO-80 mapper actually
    // emits; furniture/shoe/bottle/etc. fall through to `unknown` (which is
    // also ignored), so they're no longer asserted here. Note: `book` was
    // moved OUT of this list — it is now a needs-review toy candidate.
    const ignored = ['person', 'pet', 'furniture', 'not_toy', 'unknown'];
    for (final label in ignored) {
      final def = registry.lookup(label);
      expect(def.isIgnored, isTrue, reason: '$label should be ignored');
      expect(def.countsAsToy, isFalse, reason: '$label must not count');
    }
  });

  test('book is now a toy candidate (needs review), not auto-ignored', () {
    final def = registry.lookup('book');
    expect(def.countsAsToy, isTrue);
    expect(def.isIgnored, isFalse);
  });

  test('Phase 6.0 toy labels are all registered and count as toys', () {
    const toyLabels = [
      'stuffed_animal',
      'ball',
      'toy_car',
      'toy_truck',
      'toy_train',
      'toy_vehicle',
      'toy_outdoor',
      'book',
      'object',
    ];
    for (final label in toyLabels) {
      expect(registry.isKnown(label), isTrue, reason: '$label must register');
      final def = registry.lookup(label);
      expect(def.countsAsToy, isTrue, reason: '$label must count as toy');
      expect(def.isIgnored, isFalse, reason: '$label must not be ignored');
    }
  });
}
