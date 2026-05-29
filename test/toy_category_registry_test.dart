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

  test('all ignored negative categories are present and ignored', () {
    const ignored = [
      'person', 'pet', 'shoe', 'clothes', 'bottle', 'cup', 'furniture',
      'bed', 'pillow', 'phone', 'remote_control', 'book', 'unknown',
    ];
    for (final label in ignored) {
      final def = registry.lookup(label);
      expect(def.isIgnored, isTrue, reason: '$label should be ignored');
      expect(def.countsAsToy, isFalse, reason: '$label must not count');
    }
  });
}
