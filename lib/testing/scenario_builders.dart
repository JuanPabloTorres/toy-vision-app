import '../detection/models/raw_detection.dart';
import 'fake_detections.dart';

/// A scenario is an ordered list of frames; each frame is the raw detection
/// list a detector would emit for that frame. Scenarios drive product tests
/// over the pipeline without a real model.
typedef Scenario = List<List<RawDetection>>;

class ScenarioBuilders {
  ScenarioBuilders._();

  /// A single steady toy visible for [frames] frames.
  static Scenario oneToyVisible({int frames = 5, String label = 'toy_car'}) {
    final box = FakeDetections.box(x: 0.3, y: 0.4);
    return List.generate(
      frames,
      (_) => [FakeDetections.raw(label: label, box: box)],
    );
  }

  /// One toy that disappears for [gap] frames in the middle, then returns at
  /// roughly the same place.
  static Scenario toyDisappearsBriefly({
    int before = 4,
    int gap = 3,
    int after = 4,
  }) {
    final box = FakeDetections.box(x: 0.3, y: 0.4);
    return [
      for (var i = 0; i < before; i++) [FakeDetections.raw(box: box)],
      for (var i = 0; i < gap; i++) <RawDetection>[],
      for (var i = 0; i < after; i++) [FakeDetections.raw(box: box)],
    ];
  }

  /// Multiple distinct toys visible together for [frames] frames.
  static Scenario multipleToys({int frames = 5}) {
    final car = FakeDetections.raw(
      label: 'toy_car',
      box: FakeDetections.box(x: 0.1, y: 0.6),
    );
    final bear = FakeDetections.raw(
      label: 'stuffed_animal',
      box: FakeDetections.box(x: 0.6, y: 0.2, width: 0.22, height: 0.24),
    );
    return List.generate(frames, (_) => [car, bear]);
  }

  /// A valid toy alongside a person that must always be ignored.
  static Scenario toyWithPerson({int frames = 5}) {
    final car = FakeDetections.raw(box: FakeDetections.box(x: 0.3, y: 0.5));
    final person = FakeDetections.person(
      box: FakeDetections.box(x: 0.4, y: 0.05, width: 0.2, height: 0.55),
    );
    return List.generate(frames, (_) => [car, person]);
  }
}
