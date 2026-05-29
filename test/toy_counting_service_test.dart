import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/toy_counting_service.dart';
import 'package:toyvision_realtime/core/config/realtime_detection_config.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/tracked_toy.dart';

void main() {
  const config = RealtimeDetectionConfig(minimumStableFrames: 3);

  TrackedToy toy({int framesSeen = 1, bool counted = false, int id = 1}) {
    return TrackedToy(
      id: id,
      label: 'toy_car',
      displayName: 'Toy car',
      box: const BoundingBox(x: 0.3, y: 0.4, width: 0.2, height: 0.2),
      confidence: 0.9,
      framesSeen: framesSeen,
      hasBeenCounted: counted,
    );
  }

  test('does not count a toy before it is stable', () {
    final service = ToyCountingService(config: config);
    final summary = service.update([toy(framesSeen: 2)]);
    expect(summary.total, 0);
  });

  test('counts a toy once it reaches the stable frame threshold', () {
    final service = ToyCountingService(config: config);
    final t = toy(framesSeen: 3);
    final summary = service.update([t]);
    expect(summary.total, 1);
    expect(summary.perCategory['Toy car'], 1);
    expect(t.hasBeenCounted, isTrue);
  });

  test('never counts the same tracked toy twice (duplicate prevention)', () {
    final service = ToyCountingService(config: config);
    final t = toy(framesSeen: 3);
    service.update([t]); // counted here
    t.framesSeen = 20; // many more frames of the same toy
    final summary = service.update([t]);
    expect(summary.total, 1);
  });

  test('counts distinct stable toys separately', () {
    final service = ToyCountingService(config: config);
    final summary = service.update([
      toy(id: 1, framesSeen: 3),
      toy(id: 2, framesSeen: 5),
    ]);
    expect(summary.total, 2);
    expect(summary.perCategory['Toy car'], 2);
  });

  test('reset clears all accumulated counts', () {
    final service = ToyCountingService(config: config);
    service.update([toy(framesSeen: 3)]);
    service.reset();
    expect(service.summary.total, 0);
    expect(service.summary.perCategory, isEmpty);
  });
}
