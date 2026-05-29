import '../core/config/realtime_detection_config.dart';
import '../detection/models/detection_result.dart';
import 'iou_calculator.dart';
import 'tracked_toy.dart';

/// Matches validated detections to tracked toys across frames using IoU.
///
/// Owns tracked-object identity and missing-frame handling. It does not run
/// inference, render UI, or store permanent history. Counting decisions belong
/// to ToyCountingService; this engine only maintains identity over time.
class ToyTrackingEngine {
  ToyTrackingEngine({
    required this.config,
    IoUCalculator? iouCalculator,
  }) : _iou = iouCalculator ?? const IoUCalculator();

  final RealtimeDetectionConfig config;
  final IoUCalculator _iou;

  final List<TrackedToy> _tracked = [];
  int _nextId = 0;

  /// Read-only view of currently tracked toys (visible and briefly missing).
  List<TrackedToy> get tracked => List.unmodifiable(_tracked);

  /// Ingest the validated detections for one frame and return the updated set.
  List<TrackedToy> update(List<DetectionResult> detections) {
    final unmatchedDetections = List<int>.generate(detections.length, (i) => i);
    final matchedTracks = <int>{};

    // Greedy best-IoU matching: same label and IoU at/above threshold.
    final candidates = <_Match>[];
    for (var ti = 0; ti < _tracked.length; ti++) {
      for (final di in unmatchedDetections) {
        if (_tracked[ti].label != detections[di].label) continue;
        final score = _iou.iou(_tracked[ti].box, detections[di].box);
        if (score >= config.iouMatchThreshold) {
          candidates.add(_Match(trackIndex: ti, detectionIndex: di, iou: score));
        }
      }
    }
    candidates.sort((a, b) => b.iou.compareTo(a.iou));

    final usedDetections = <int>{};
    for (final m in candidates) {
      if (matchedTracks.contains(m.trackIndex)) continue;
      if (usedDetections.contains(m.detectionIndex)) continue;
      matchedTracks.add(m.trackIndex);
      usedDetections.add(m.detectionIndex);

      final track = _tracked[m.trackIndex];
      final det = detections[m.detectionIndex];
      track.box = det.box;
      track.confidence = det.confidence;
      track.framesSeen += 1;
      track.framesMissing = 0;
    }

    // Unmatched existing tracks age; drop those missing too long.
    for (var ti = 0; ti < _tracked.length; ti++) {
      if (!matchedTracks.contains(ti)) {
        _tracked[ti].framesMissing += 1;
      }
    }
    _tracked.removeWhere(
      (t) => t.framesMissing > config.maximumMissingFrames,
    );

    // Unmatched detections become new tracked toys.
    for (var di = 0; di < detections.length; di++) {
      if (usedDetections.contains(di)) continue;
      final det = detections[di];
      _tracked.add(
        TrackedToy(
          id: _nextId++,
          label: det.label,
          displayName: det.displayName,
          box: det.box,
          confidence: det.confidence,
        ),
      );
    }

    return tracked;
  }

  /// Clear all tracked identities (used by the reset action).
  void reset() {
    _tracked.clear();
    _nextId = 0;
  }
}

class _Match {
  const _Match({
    required this.trackIndex,
    required this.detectionIndex,
    required this.iou,
  });

  final int trackIndex;
  final int detectionIndex;
  final double iou;
}
