import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/one_pass_toy_selection_service.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';

/// Unit tests for the pure one-pass selector: given one frame's candidates it
/// returns the single best toy to lock onto, applying the spec's scoring
/// priority (confidence first, center proximity breaks ties) and eligibility
/// floors (valid box, big enough, stable enough). It never decides whether to
/// switch off an existing target — that hard lock lives in the controller.

ToySelectionCandidate _candidate({
  required int id,
  double confidence = 0.8,
  double cx = 0.5,
  double cy = 0.5,
  double size = 0.2,
  int framesSeen = 3,
}) {
  return ToySelectionCandidate(
    id: id,
    confidence: confidence,
    framesSeen: framesSeen,
    box: BoundingBox(
      x: (cx - size / 2).clamp(0.0, 1.0 - size),
      y: (cy - size / 2).clamp(0.0, 1.0 - size),
      width: size,
      height: size,
    ),
  );
}

void main() {
  const selector = OnePassToySelectionService();

  group('OnePassToySelectionService', () {
    test('no candidates → no selection', () {
      expect(selector.selectBest(const []).hasSelection, isFalse);
      expect(selector.selectBest(const []).selectedId, isNull);
      expect(
        selector.selectBest(const []).reason,
        ToySelectionReason.none,
      );
    });

    test('a single eligible candidate is selected', () {
      final decision = selector.selectBest([_candidate(id: 7)]);
      expect(decision.selectedId, 7);
      expect(
        decision.reason,
        ToySelectionReason.highestConfidenceClosestToCenter,
      );
    });

    test('priority #1: higher confidence wins (same position)', () {
      final decision = selector.selectBest([
        _candidate(id: 1, confidence: 0.60, cx: 0.5),
        _candidate(id: 2, confidence: 0.90, cx: 0.5),
      ]);
      expect(decision.selectedId, 2);
    });

    test('priority #2: equal confidence → closer to center wins', () {
      final decision = selector.selectBest([
        _candidate(id: 1, confidence: 0.8, cx: 0.10), // off to the edge
        _candidate(id: 2, confidence: 0.8, cx: 0.50), // dead center
      ]);
      expect(decision.selectedId, 2);
    });

    test('confidence DOMINATES center: a far, much more confident toy still '
        'beats a dead-center weaker one', () {
      final decision = selector.selectBest([
        _candidate(id: 1, confidence: 0.99, cx: 0.12), // far but very sure
        _candidate(id: 2, confidence: 0.55, cx: 0.50), // centered but unsure
      ]);
      expect(
        decision.selectedId,
        1,
        reason: 'a 0.25+ confidence gap cannot be overturned by position',
      );
    });

    test('an invalid (out-of-frame) box is rejected', () {
      // A box that runs past the frame edge is not a valid candidate.
      const bad = ToySelectionCandidate(
        id: 1,
        confidence: 0.95,
        framesSeen: 3,
        box: BoundingBox(x: 0.9, y: 0.2, width: 0.4, height: 0.2),
      );
      final good = _candidate(id: 2, confidence: 0.5);
      expect(selector.selectBest([bad, good]).selectedId, 2);
      expect(selector.selectBest([bad]).hasSelection, isFalse);
    });

    test('too-small boxes are rejected when a min area floor is set', () {
      const sizing = OnePassToySelectionService(minBoxAreaFraction: 0.02);
      final tiny = _candidate(id: 1, confidence: 0.99, size: 0.08); // area .0064
      final big = _candidate(id: 2, confidence: 0.6, size: 0.30); // area .09
      expect(sizing.selectBest([tiny, big]).selectedId, 2);
      expect(sizing.selectBest([tiny]).hasSelection, isFalse);
    });

    test('candidates below the stability floor are rejected', () {
      const stable = OnePassToySelectionService(minStableFrames: 3);
      final blip = _candidate(id: 1, confidence: 0.99, framesSeen: 1);
      final steady = _candidate(id: 2, confidence: 0.6, framesSeen: 3);
      expect(stable.selectBest([blip, steady]).selectedId, 2);
      expect(stable.selectBest([blip]).hasSelection, isFalse);
    });
  });
}
