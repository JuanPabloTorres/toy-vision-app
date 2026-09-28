import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/core/performance/adaptive_inference_scheduler.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';

import '../support/camera_replay.dart';

void main() {
  const scheduler = AdaptiveInferenceScheduler();

  test('raises cadence only while disappearance needs verification', () {
    final policy = scheduler.evaluate(
      sceneState: SceneState.stable,
      motion: 0,
      deviceHealth: const DeviceHealth(),
      activeTracks: 2,
      possibleDisappearance: true,
      discoveryMode: false,
    );

    expect(policy.targetFps, 12);
    expect(policy.runOpenSetProposals, isTrue);
    expect(policy.reason, 'verify_disappearance');
  });

  test('critical thermal state has priority and disables open-set work', () {
    final policy = scheduler.evaluate(
      sceneState: SceneState.moving,
      motion: 1,
      deviceHealth: const DeviceHealth(
        thermalState: ThermalState.critical,
        batteryLevel: 1,
        isCharging: true,
      ),
      activeTracks: 0,
      possibleDisappearance: true,
      discoveryMode: true,
    );

    expect(policy.targetFps, 3);
    expect(policy.runOpenSetProposals, isFalse);
    expect(policy.reason, 'thermal_critical');
  });

  test('keeps enough cadence to observe a physical pickup', () {
    final policy = scheduler.evaluate(
      sceneState: SceneState.stable,
      motion: 0,
      deviceHealth: const DeviceHealth(),
      activeTracks: 1,
      possibleDisappearance: false,
      discoveryMode: false,
    );

    expect(policy.targetFps, 10);
    expect(policy.reason, 'awaiting_physical_pickup');
  });

  test('engine actually skips open-set proposals under thermal pressure',
      () async {
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine()
      ..updateDeviceHealth(
        const DeviceHealth(thermalState: ThermalState.serious),
      );
    final source = replay.frames.first;
    final result = await engine.processFrame(
      replay.render(
        ReplayFrame(
          milliseconds: source.milliseconds,
          background: source.background,
          toy: true,
          detect: false,
        ),
        frameId: 0,
        origin: DateTime.utc(2026),
      ),
      discoveryMode: true,
    );

    expect(result.metrics.openSetProposalCount, 0);
    expect(result.metrics.targetInferenceFps, 5);
  });
}
