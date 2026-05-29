import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';

void main() {
  test('emits toys plus a person and a low-confidence toy by default', () {
    final detector = MockToyDetector();
    final frame = detector.detectAt(0);
    final labels = frame.map((d) => d.label).toList();
    expect(labels, contains('toy_car'));
    expect(labels, contains('stuffed_animal'));
    expect(labels, contains('person'));
    expect(labels, contains('doll'));
  });

  test('all emitted boxes are valid (within frame, positive size)', () {
    final detector = MockToyDetector();
    for (var f = 0; f < 50; f++) {
      for (final d in detector.detectAt(f)) {
        expect(d.box.isValid, isTrue, reason: 'frame $f label ${d.label}');
      }
    }
  });

  test('detectAt is deterministic for a given frame index', () {
    final a = MockToyDetector();
    final b = MockToyDetector();
    final fa = a.detectAt(7);
    final fb = b.detectAt(7);
    expect(fa.length, fb.length);
    for (var i = 0; i < fa.length; i++) {
      expect(fa[i].label, fb[i].label);
      expect(fa[i].box.x, closeTo(fb[i].box.x, 1e-12));
    }
  });

  test('can disable the person and low-confidence emissions', () {
    final detector =
        MockToyDetector(emitPerson: false, emitLowConfidenceToy: false);
    final labels = detector.detectAt(0).map((d) => d.label).toSet();
    expect(labels, isNot(contains('person')));
    expect(labels, isNot(contains('doll')));
  });
}
