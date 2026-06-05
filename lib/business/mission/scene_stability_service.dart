import 'dart:math' as math;

import '../../detection/models/bounding_box.dart';
import '../../tracking/tracked_toy.dart';

enum SceneStabilityStatus {
  stable,
  probablyMoved,
  insufficientEvidence,
}

enum SceneStabilityReason {
  stableBecauseAnchorsPersisted,
  stableBecauseTargetDisappearedButSceneStayedConsistent,
  movedBecauseAnchorLossWasHigh,
  movedBecauseSpatialDistributionChanged,
  movedBecauseVisibleTrackCountChangedAbruptly,
  movedBecauseUnrelatedRawAppearedAfterTargetLoss,
  insufficientBecauseNoReliableAnchors,
  insufficientBecauseNotEnoughHistory,
}

class SceneStabilityResult {
  const SceneStabilityResult({
    required this.status,
    required this.reason,
    required this.score,
    required this.framesEvaluated,
    required this.anchorContinuity,
    required this.averageCenterShift,
  });

  final SceneStabilityStatus status;
  final SceneStabilityReason reason;
  final double score;
  final int framesEvaluated;
  final double anchorContinuity;
  final double averageCenterShift;
}

class _SceneFrameResult {
  const _SceneFrameResult({
    required this.status,
    required this.reason,
    required this.score,
    required this.anchorContinuity,
    required this.averageCenterShift,
  });

  final SceneStabilityStatus status;
  final SceneStabilityReason reason;
  final double score;
  final double anchorContinuity;
  final double averageCenterShift;
}

/// Temporal scene stability check using signals already available in the live
/// loop. It refuses to call a scene stable without reliable anchors: seeing
/// raw non-toy classes only proves the camera sees something, not that it is
/// still pointed at the same area.
class SceneStabilityService {
  SceneStabilityService({
    this.maxAverageAnchorCenterShift = 0.18,
    this.maxAnchorLossRatio = 0.55,
    this.maxVisibleTrackCountDelta = 2,
    this.windowSize = 5,
    this.requiredStableFrames = 3,
  });

  final double maxAverageAnchorCenterShift;
  final double maxAnchorLossRatio;
  final int maxVisibleTrackCountDelta;
  final int windowSize;
  final int requiredStableFrames;

  final List<_SceneFrameResult> _history = [];

  void reset() => _history.clear();

  SceneStabilityStatus evaluate({
    required Map<int, BoundingBox> anchorBoxes,
    required List<TrackedToy> visibleToys,
    List<String> rawClassNames = const [],
    bool targetMissing = false,
  }) =>
      _evaluateFrame(
        anchorBoxes: anchorBoxes,
        visibleToys: visibleToys,
        rawClassNames: rawClassNames,
        targetMissing: targetMissing,
      ).status;

  SceneStabilityResult evaluateDetailed({
    required Map<int, BoundingBox> anchorBoxes,
    required List<TrackedToy> visibleToys,
    List<String> rawClassNames = const [],
    bool targetMissing = false,
  }) {
    final frame = _evaluateFrame(
      anchorBoxes: anchorBoxes,
      visibleToys: visibleToys,
      rawClassNames: rawClassNames,
      targetMissing: targetMissing,
    );
    _history.add(frame);
    if (_history.length > windowSize) _history.removeAt(0);

    if (frame.status == SceneStabilityStatus.probablyMoved) {
      return _toResult(frame);
    }
    if (frame.status == SceneStabilityStatus.insufficientEvidence) {
      return _toResult(frame);
    }

    final stableFrames =
        _history.where((f) => f.status == SceneStabilityStatus.stable).length;
    if (stableFrames < requiredStableFrames) {
      return SceneStabilityResult(
        status: SceneStabilityStatus.insufficientEvidence,
        reason: SceneStabilityReason.insufficientBecauseNotEnoughHistory,
        score: frame.score * (stableFrames / requiredStableFrames),
        framesEvaluated: _history.length,
        anchorContinuity: frame.anchorContinuity,
        averageCenterShift: frame.averageCenterShift,
      );
    }

    return _toResult(frame);
  }

  SceneStabilityResult _toResult(_SceneFrameResult frame) =>
      SceneStabilityResult(
        status: frame.status,
        reason: frame.reason,
        score: frame.score,
        framesEvaluated: _history.length,
        anchorContinuity: frame.anchorContinuity,
        averageCenterShift: frame.averageCenterShift,
      );

  _SceneFrameResult _evaluateFrame({
    required Map<int, BoundingBox> anchorBoxes,
    required List<TrackedToy> visibleToys,
    required List<String> rawClassNames,
    required bool targetMissing,
  }) {
    if (anchorBoxes.isEmpty) {
      return const _SceneFrameResult(
        status: SceneStabilityStatus.insufficientEvidence,
        reason: SceneStabilityReason.insufficientBecauseNoReliableAnchors,
        score: 0,
        anchorContinuity: 0,
        averageCenterShift: double.infinity,
      );
    }

    final visibleById = {
      for (final toy in visibleToys)
        if (toy.isVisible) toy.id: toy,
    };
    final anchorDistances = <double>[];
    for (final entry in anchorBoxes.entries) {
      final current = visibleById[entry.key];
      if (current == null) continue;
      anchorDistances.add(_centerDistance(entry.value, current.box));
    }

    final continuity = anchorDistances.length / anchorBoxes.length;
    final lossRatio = 1 - continuity;
    final unrelatedRaw = rawClassNames.any(_isClearlyNonToyRawLabel);

    if (targetMissing && unrelatedRaw) {
      return _moved(
        SceneStabilityReason.movedBecauseUnrelatedRawAppearedAfterTargetLoss,
        continuity,
        anchorDistances,
      );
    }

    if (anchorDistances.isEmpty) {
      return rawClassNames.isEmpty
          ? const _SceneFrameResult(
              status: SceneStabilityStatus.insufficientEvidence,
              reason: SceneStabilityReason.insufficientBecauseNoReliableAnchors,
              score: 0,
              anchorContinuity: 0,
              averageCenterShift: double.infinity,
            )
          : _moved(
              SceneStabilityReason.movedBecauseAnchorLossWasHigh,
              continuity,
              anchorDistances,
            );
    }

    if (lossRatio > maxAnchorLossRatio) {
      return _moved(
        SceneStabilityReason.movedBecauseAnchorLossWasHigh,
        continuity,
        anchorDistances,
      );
    }

    final visibleDelta = (visibleById.length - anchorBoxes.length).abs();
    if (visibleDelta > maxVisibleTrackCountDelta) {
      return _moved(
        SceneStabilityReason.movedBecauseVisibleTrackCountChangedAbruptly,
        continuity,
        anchorDistances,
      );
    }

    final averageDistance =
        anchorDistances.reduce((a, b) => a + b) / anchorDistances.length;
    if (averageDistance > maxAverageAnchorCenterShift) {
      return _moved(
        SceneStabilityReason.movedBecauseSpatialDistributionChanged,
        continuity,
        anchorDistances,
      );
    }

    final score = (1 - averageDistance / maxAverageAnchorCenterShift)
        .clamp(0.0, 1.0)
        .toDouble();
    return _SceneFrameResult(
      status: SceneStabilityStatus.stable,
      reason: targetMissing
          ? SceneStabilityReason
              .stableBecauseTargetDisappearedButSceneStayedConsistent
          : SceneStabilityReason.stableBecauseAnchorsPersisted,
      score: score,
      anchorContinuity: continuity,
      averageCenterShift: averageDistance,
    );
  }

  _SceneFrameResult _moved(
    SceneStabilityReason reason,
    double continuity,
    List<double> anchorDistances,
  ) {
    final averageDistance = anchorDistances.isEmpty
        ? double.infinity
        : anchorDistances.reduce((a, b) => a + b) / anchorDistances.length;
    return _SceneFrameResult(
      status: SceneStabilityStatus.probablyMoved,
      reason: reason,
      score: 0,
      anchorContinuity: continuity,
      averageCenterShift: averageDistance,
    );
  }

  bool _isClearlyNonToyRawLabel(String rawLabel) {
    final label = rawLabel.trim().toLowerCase().replaceAll('_', ' ');
    const toyLike = {
      'toy',
      'red toy',
      'blue toy',
      'small toy',
      'plastic toy',
      'teddy bear',
      'sports ball',
      'ball',
      'car',
      'truck',
      'train',
      'airplane',
      'kite',
      'frisbee',
      'skateboard',
    };
    return label.isNotEmpty && !toyLike.contains(label);
  }

  double _centerDistance(BoundingBox a, BoundingBox b) {
    final dx = a.centerX - b.centerX;
    final dy = a.centerY - b.centerY;
    return math.sqrt(dx * dx + dy * dy);
  }
}
