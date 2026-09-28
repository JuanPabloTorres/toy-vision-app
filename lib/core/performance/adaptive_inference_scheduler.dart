import '../../domain/scene/scene_state.dart';

enum ThermalState { nominal, fair, serious, critical }

class DeviceHealth {
  const DeviceHealth({
    this.thermalState = ThermalState.nominal,
    this.batteryLevel = 1,
    this.isCharging = false,
  });

  final ThermalState thermalState;
  final double batteryLevel;
  final bool isCharging;
}

class InferencePolicy {
  const InferencePolicy({
    required this.targetFps,
    required this.runOpenSetProposals,
    required this.reason,
  });

  final int targetFps;
  final bool runOpenSetProposals;
  final String reason;
}

class AdaptiveInferenceScheduler {
  const AdaptiveInferenceScheduler();

  InferencePolicy evaluate({
    required SceneState sceneState,
    required double motion,
    required DeviceHealth deviceHealth,
    required int activeTracks,
    required bool possibleDisappearance,
    required bool discoveryMode,
  }) {
    if (deviceHealth.thermalState == ThermalState.critical) {
      return const InferencePolicy(
        targetFps: 3,
        runOpenSetProposals: false,
        reason: 'thermal_critical',
      );
    }
    if (deviceHealth.thermalState == ThermalState.serious) {
      return const InferencePolicy(
        targetFps: 5,
        runOpenSetProposals: false,
        reason: 'thermal_serious',
      );
    }
    if (deviceHealth.batteryLevel <= 0.15 && !deviceHealth.isCharging) {
      return const InferencePolicy(
        targetFps: 5,
        runOpenSetProposals: true,
        reason: 'battery_low',
      );
    }
    if (possibleDisappearance) {
      return const InferencePolicy(
        targetFps: 12,
        runOpenSetProposals: true,
        reason: 'verify_disappearance',
      );
    }
    if (discoveryMode) {
      return const InferencePolicy(
        targetFps: 8,
        runOpenSetProposals: true,
        reason: 'initial_scan',
      );
    }
    if (sceneState == SceneState.moving || motion >= 0.12) {
      return const InferencePolicy(
        targetFps: 10,
        runOpenSetProposals: true,
        reason: 'motion',
      );
    }
    // During cleanup the physical lift can happen between two frames. Five
    // FPS left a 200 ms blind interval and frequently missed the only visible
    // movement before the toy disappeared. Keep a higher cadence while a
    // confirmed target is present; thermal and battery guards above still cap
    // this work when the device needs protection.
    if (activeTracks > 0) {
      return const InferencePolicy(
        targetFps: 10,
        runOpenSetProposals: true,
        reason: 'awaiting_physical_pickup',
      );
    }
    return const InferencePolicy(
      targetFps: 7,
      runOpenSetProposals: true,
      reason: 'searching',
    );
  }
}
