import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/core/config/realtime_detection_config.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/detection/models/detection_result.dart';
import 'package:toyvision_realtime/tracking/toy_tracking_engine.dart';

void main() {
  const config = RealtimeDetectionConfig(
    minimumStableFrames: 3,
    maximumMissingFrames: 10,
    iouMatchThreshold: 0.45,
  );

  DetectionResult det(double x, double y, {String label = 'toy_car'}) {
    return DetectionResult(
      label: label,
      displayName: 'Toy car',
      confidence: 0.9,
      box: BoundingBox(x: x, y: y, width: 0.2, height: 0.2),
    );
  }

  test('a steady toy keeps one identity across frames', () {
    final engine = ToyTrackingEngine(config: config);
    engine.update([det(0.3, 0.4)]);
    engine.update([det(0.3, 0.4)]);
    final tracked = engine.update([det(0.3, 0.4)]);
    expect(tracked, hasLength(1));
    expect(tracked.single.id, 0);
    expect(tracked.single.framesSeen, 3);
  });

  test('a small movement (high IoU) keeps the same identity', () {
    final engine = ToyTrackingEngine(config: config);
    final id0 = engine.update([det(0.30, 0.40)]).single.id;
    final tracked = engine.update([det(0.32, 0.40)]);
    expect(tracked, hasLength(1));
    expect(tracked.single.id, id0);
  });

  test('a large jump (no overlap) creates a new identity', () {
    final engine = ToyTrackingEngine(config: config);
    engine.update([det(0.30, 0.40)]);
    final tracked = engine.update([det(0.80, 0.80)]);
    final ids = tracked.map((t) => t.id).toSet();
    expect(ids.length, 2);
  });

  test('brief disappearance within the window keeps identity', () {
    final engine = ToyTrackingEngine(config: config);
    engine.update([det(0.3, 0.4)]);
    engine.update([det(0.3, 0.4)]);
    engine.update(const []); // missing 1
    engine.update(const []); // missing 2
    final tracked = engine.update([det(0.3, 0.4)]); // returns
    expect(tracked, hasLength(1));
    expect(tracked.single.id, 0);
    expect(tracked.single.framesMissing, 0);
  });

  test('a toy missing beyond the limit is dropped', () {
    final engine = ToyTrackingEngine(config: config);
    engine.update([det(0.3, 0.4)]);
    for (var i = 0; i < config.maximumMissingFrames + 1; i++) {
      engine.update(const []);
    }
    expect(engine.tracked, isEmpty);
  });

  test(
      'a camera pan that drops IoU below the match threshold STILL keeps the '
      'same identity (proximity carries the match)', () {
    // 0.10 shift per frame on a 0.20 box → frame-to-frame IoU ≈ 0.33, below
    // iouMatchThreshold (0.45). The OLD IoU-only tracker re-issued a new id
    // here (the "yellow box jumps" bug); the blended score must hold the id.
    final engine = ToyTrackingEngine(config: config);
    final id0 = engine.update([det(0.20, 0.40)]).single.id;
    var tracked = engine.update([det(0.30, 0.40)]);
    expect(tracked, hasLength(1));
    expect(tracked.single.id, id0);
    tracked = engine.update([det(0.40, 0.40)]);
    expect(tracked, hasLength(1));
    expect(tracked.single.id, id0);
  });

  test('class flicker (same spot, different label) keeps the same identity',
      () {
    // The detector relabels the same physical toy between frames. Strong
    // overlap must outweigh the changed class name so the id is stable.
    final engine = ToyTrackingEngine(config: config);
    final id0 = engine.update([det(0.30, 0.40, label: 'toy_car')]).single.id;
    final tracked = engine.update([det(0.30, 0.40, label: 'stuffed_animal')]);
    expect(tracked, hasLength(1));
    expect(tracked.single.id, id0);
    expect(tracked.single.label, 'stuffed_animal'); // label refreshed
  });

  test('two distinct toys never merge under the blended score (across frames)',
      () {
    final engine = ToyTrackingEngine(config: config);
    final idA = engine.update([det(0.10, 0.40)]).single.id;
    final tracked = engine.update([det(0.10, 0.40), det(0.70, 0.40)]);
    expect(tracked, hasLength(2));
    final ids = tracked.map((t) => t.id).toSet();
    expect(ids, contains(idA)); // toy A kept its id
    expect(ids.length, 2); // toy B got its own — no merge
  });

  test('distinct toys get distinct identities', () {
    final engine = ToyTrackingEngine(config: config);
    final tracked = engine.update([
      det(0.1, 0.6, label: 'toy_car'),
      det(0.6, 0.2, label: 'stuffed_animal'),
    ]);
    expect(tracked, hasLength(2));
    expect(tracked.map((t) => t.id).toSet().length, 2);
  });

  test('reset clears all tracked identities', () {
    final engine = ToyTrackingEngine(config: config);
    engine.update([det(0.3, 0.4)]);
    engine.reset();
    expect(engine.tracked, isEmpty);
  });
}
