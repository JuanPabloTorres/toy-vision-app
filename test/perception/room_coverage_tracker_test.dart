import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/scene/spatial_observation.dart';
import 'package:toyvision_realtime/perception/coverage/room_coverage_tracker.dart';

void main() {
  test('rotation vector covers left, center, right and floor', () {
    final tracker = RoomCoverageTracker(minimumDirectionalSectors: 4);

    tracker.observe(_scene(yaw: 0, pitch: 0, orientation: true));
    tracker.observe(_scene(yaw: -35, pitch: 0, orientation: true));
    tracker.observe(_scene(yaw: 35, pitch: 0, orientation: true));
    final result =
        tracker.observe(_scene(yaw: 0, pitch: 25, orientation: true));

    expect(result.coverage, 1);
    expect(
      result.visited,
      containsAll([
        RoomCoverageSector.left,
        RoomCoverageSector.center,
        RoomCoverageSector.right,
        RoomCoverageSector.floorCenter,
      ]),
    );
    expect(result.nextRequired, isNotNull);
  });

  test('unsupported devices fall back to distinct visual viewpoints', () {
    final tracker = RoomCoverageTracker(minimumFallbackViewpoints: 2);

    final first = tracker.observe(_scene(embedding: const [1, 0]));
    final second = tracker.observe(_scene(embedding: const [0, 1]));

    expect(first.coverage, 0.5);
    expect(second.coverage, 1);
    expect(second.usesDeviceOrientation, isFalse);
  });
}

SceneDescriptor _scene({
  double yaw = 0,
  double pitch = 0,
  List<double> embedding = const [1, 0],
  bool orientation = false,
}) {
  final now = DateTime.utc(2026);
  return SceneDescriptor(
    embedding: embedding,
    state: SceneState.stable,
    similarityToPrevious: 0.99,
    motion: 0.01,
    sharpness: 0.2,
    luminance: 0.5,
    coverage: 1,
    timestamp: now,
    stableFrameCount: 10,
    similarityToStableAnchor: 0.99,
    spatial: orientation
        ? SpatialObservation(
            timestamp: now,
            motionAvailable: true,
            orientationAvailable: true,
            gyroscopeRadPerSecond: 0.01,
            linearAccelerationMetersPerSecond2: 0.01,
            yawDegrees: yaw,
            pitchDegrees: pitch,
          )
        : const SpatialObservation.unavailable(),
  );
}
