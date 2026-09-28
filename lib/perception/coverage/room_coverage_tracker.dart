import 'dart:math' as math;

import '../../core/math/vector_math.dart';
import '../../domain/scene/scene_descriptor.dart';

enum RoomCoverageSector {
  left,
  center,
  right,
  floorLeft,
  floorCenter,
  floorRight,
}

class RoomCoverageSnapshot {
  const RoomCoverageSnapshot({
    required this.visited,
    required this.coverage,
    required this.nextRequired,
    required this.usesDeviceOrientation,
  });

  final Set<RoomCoverageSector> visited;
  final double coverage;
  final RoomCoverageSector? nextRequired;
  final bool usesDeviceOrientation;
}

/// Tracks inspected directions. Falls back to visual viewpoints when device
/// orientation is unavailable, so unsupported devices never dead-end.
class RoomCoverageTracker {
  RoomCoverageTracker({
    this.minimumHorizontalRegions = 3,
    this.minimumVisualViewpoints = 2,
    this.viewpointSimilarityThreshold = 0.92,
  });

  final int minimumHorizontalRegions;
  final int minimumVisualViewpoints;
  final double viewpointSimilarityThreshold;

  final Set<RoomCoverageSector> _visited = {};
  final List<List<double>> _fallbackViewpoints = [];
  double? _originYaw;
  double? _originPitch;

  RoomCoverageSnapshot observe(SceneDescriptor scene) {
    final spatial = scene.spatial;
    final yaw = spatial.yawDegrees;
    final pitch = spatial.pitchDegrees;
    final orientationUsable = spatial.orientationAvailable &&
        spatial.cameraTrackingGood &&
        scene.canVerifyDisappearance &&
        yaw != null &&
        pitch != null;
    if (scene.canVerifyDisappearance &&
        scene.embedding.isNotEmpty &&
        _fallbackViewpoints.every(
          (viewpoint) =>
              cosineSimilarity(viewpoint, scene.embedding) <
              viewpointSimilarityThreshold,
        )) {
      _fallbackViewpoints.add(List<double>.from(scene.embedding));
    }
    if (orientationUsable) {
      _originYaw ??= yaw;
      _originPitch ??= pitch;
      final horizontal = _horizontalSector(_angleDelta(yaw, _originYaw!));
      final lookingAtFloor = pitch - _originPitch! >= 18;
      _visited.add(lookingAtFloor ? _floorSector(horizontal) : horizontal);
    }
    // A short pan makes the current frame unsuitable for adding coverage, but
    // it must not switch an established orientation sweep to the fallback
    // denominator and make visible progress jump back to zero.
    return snapshot();
  }

  RoomCoverageSnapshot snapshot({bool? usesDeviceOrientation}) {
    final orientation = usesDeviceOrientation ?? _originYaw != null;
    final horizontalRegions = _visited.map(_horizontalFamily).toSet();
    final directionalProgress = minimumHorizontalRegions <= 0
        ? 1.0
        : (horizontalRegions.length / minimumHorizontalRegions).clamp(0.0, 1.0);
    final visualProgress = minimumVisualViewpoints <= 0
        ? 1.0
        : (_fallbackViewpoints.length / minimumVisualViewpoints)
            .clamp(0.0, 1.0);
    // Device orientation is helpful but not a completion dependency. Some
    // phones start the final sweep already pointed at the floor, making a
    // relative "look farther down" sector unreachable. Either the configured
    // spatial regions or stable visual viewpoints now prove coverage.
    final progress = orientation
        ? math.max(directionalProgress, visualProgress)
        : visualProgress;
    return RoomCoverageSnapshot(
      visited: Set.unmodifiable(_visited),
      coverage: progress,
      nextRequired:
          orientation && progress < 1 ? _nextRequired(horizontalRegions) : null,
      usesDeviceOrientation: orientation,
    );
  }

  void reset() {
    _visited.clear();
    _fallbackViewpoints.clear();
    _originYaw = null;
    _originPitch = null;
  }

  RoomCoverageSector _horizontalSector(double yawDelta) {
    if (yawDelta <= -22) return RoomCoverageSector.left;
    if (yawDelta >= 22) return RoomCoverageSector.right;
    return RoomCoverageSector.center;
  }

  RoomCoverageSector _floorSector(RoomCoverageSector horizontal) =>
      switch (horizontal) {
        RoomCoverageSector.left => RoomCoverageSector.floorLeft,
        RoomCoverageSector.right => RoomCoverageSector.floorRight,
        _ => RoomCoverageSector.floorCenter,
      };

  RoomCoverageSector _horizontalFamily(RoomCoverageSector sector) =>
      switch (sector) {
        RoomCoverageSector.left ||
        RoomCoverageSector.floorLeft =>
          RoomCoverageSector.left,
        RoomCoverageSector.right ||
        RoomCoverageSector.floorRight =>
          RoomCoverageSector.right,
        _ => RoomCoverageSector.center,
      };

  RoomCoverageSector? _nextRequired(Set<RoomCoverageSector> horizontalRegions) {
    const order = [
      RoomCoverageSector.left,
      RoomCoverageSector.center,
      RoomCoverageSector.right,
    ];
    for (final sector in order) {
      if (!horizontalRegions.contains(sector)) return sector;
    }
    return null;
  }

  double _angleDelta(double value, double origin) {
    var delta = value - origin;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    return delta;
  }
}
