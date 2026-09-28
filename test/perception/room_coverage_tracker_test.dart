import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/scene/spatial_observation.dart';
import 'package:toyvision_realtime/perception/coverage/room_coverage_tracker.dart';

void main() {
  test('floor-first horizontal sweep has an achievable completion path', () {
    final tracker = RoomCoverageTracker(minimumHorizontalRegions: 3);

    tracker.observe(_scene(yaw: 0, pitch: 55, orientation: true));
    tracker.observe(_scene(yaw: -35, pitch: 55, orientation: true));
    final result = tracker.observe(
      _scene(yaw: 35, pitch: 55, orientation: true),
    );

    expect(result.coverage, 1);
    expect(
      result.visited,
      containsAll([
        RoomCoverageSector.left,
        RoomCoverageSector.center,
        RoomCoverageSector.right,
      ]),
    );
    expect(result.nextRequired, isNull);
  });

  test('unsupported devices fall back to distinct visual viewpoints', () {
    final tracker = RoomCoverageTracker(minimumVisualViewpoints: 2);

    final first = tracker.observe(_scene(embedding: const [1, 0]));
    final second = tracker.observe(_scene(embedding: const [0, 1]));

    expect(first.coverage, 0.5);
    expect(second.coverage, 1);
    expect(second.usesDeviceOrientation, isFalse);
  });

  test('camera motion preserves directional progress already earned', () {
    final tracker = RoomCoverageTracker(minimumHorizontalRegions: 3);

    final stable = tracker.observe(
      _scene(yaw: 0, pitch: 0, orientation: true),
    );
    final moving = tracker.observe(
      _scene(
        yaw: 8,
        pitch: 0,
        orientation: true,
        state: SceneState.moving,
        stableFrameCount: 0,
        gyroscope: 1.2,
      ),
    );

    expect(stable.coverage, 0.5);
    expect(moving.coverage, 0.5);
    expect(moving.usesDeviceOrientation, isTrue);
    expect(moving.visited, contains(RoomCoverageSector.center));
  });

  test('distinct stable views can finish even when orientation is available',
      () {
    final tracker = RoomCoverageTracker(
      minimumHorizontalRegions: 3,
      minimumVisualViewpoints: 3,
    );

    tracker.observe(
      _scene(yaw: 0, pitch: 55, orientation: true, embedding: const [1, 0, 0]),
    );
    tracker.observe(
      _scene(yaw: 5, pitch: 55, orientation: true, embedding: const [0, 1, 0]),
    );
    final result = tracker.observe(
      _scene(yaw: 10, pitch: 55, orientation: true, embedding: const [0, 0, 1]),
    );

    expect(result.coverage, 1);
    expect(result.nextRequired, isNull);
  });
}

SceneDescriptor _scene({
  double yaw = 0,
  double pitch = 0,
  List<double> embedding = const [1, 0],
  bool orientation = false,
  SceneState state = SceneState.stable,
  int stableFrameCount = 10,
  double gyroscope = 0.01,
}) {
  final now = DateTime.utc(2026);
  return SceneDescriptor(
    embedding: embedding,
    state: state,
    similarityToPrevious: 0.99,
    motion: 0.01,
    sharpness: 0.2,
    luminance: 0.5,
    coverage: 1,
    timestamp: now,
    stableFrameCount: stableFrameCount,
    similarityToStableAnchor: 0.99,
    spatial: orientation
        ? SpatialObservation(
            timestamp: now,
            motionAvailable: true,
            orientationAvailable: true,
            gyroscopeRadPerSecond: gyroscope,
            linearAccelerationMetersPerSecond2: 0.01,
            yawDegrees: yaw,
            pitchDegrees: pitch,
          )
        : const SpatialObservation.unavailable(),
  );
}
