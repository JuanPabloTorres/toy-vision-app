import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_category_registry.dart';
import 'package:toyvision_realtime/detection/detectors/mlkit/mlkit_label_map.dart';

void main() {
  final registry = ToyCategoryRegistry.standard();

  test('every ML Kit category maps to a registered label', () {
    for (final label in MlKitLabelMap.producedLabels) {
      expect(
        registry.isKnown(label),
        isTrue,
        reason: 'ML Kit label "$label" must be registered',
      );
    }
  });

  test('home good maps to a toy-counting label', () {
    final label = MlKitLabelMap.toRegistryLabel('Home good');
    expect(label, 'home_good');
    expect(registry.lookup(label).countsAsToy, isTrue);
  });

  test('unclassified object maps to a toy-counting label', () {
    final label = MlKitLabelMap.toRegistryLabel('some-unknown-category');
    expect(label, MlKitLabelMap.unclassifiedLabel);
    expect(registry.lookup(label).countsAsToy, isTrue);
  });

  test('food, plant, fashion good, place are ignored', () {
    for (final source in ['Food', 'Plant', 'Fashion good', 'Place']) {
      final label = MlKitLabelMap.toRegistryLabel(source);
      expect(
        registry.lookup(label).isIgnored,
        isTrue,
        reason: '"$source" → "$label" should be ignored',
      );
    }
  });

  test('mapping is case-insensitive and tolerates whitespace', () {
    expect(MlKitLabelMap.toRegistryLabel('home good'), 'home_good');
    expect(MlKitLabelMap.toRegistryLabel('HOME GOOD'), 'home_good');
    expect(MlKitLabelMap.toRegistryLabel('  Home good  '), 'home_good');
  });
}
