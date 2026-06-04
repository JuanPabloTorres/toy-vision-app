import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../core/config/realtime_detection_config.dart';
import '../detection/models/bounding_box.dart';
import '../detection/models/detection_result.dart';
import 'iou_calculator.dart';
import 'tracked_toy.dart';

/// Matches validated detections to tracked toys across frames so each physical
/// toy keeps ONE stable identity for the whole mission.
///
/// Owns tracked-object identity and missing-frame handling. It does not run
/// inference, render UI, or store permanent history. Counting decisions belong
/// to ToyCountingService; this engine only maintains identity over time.
///
/// Association is deliberately richer than plain IoU: a moving camera shifts a
/// toy's box faster than its own size, so frame-to-frame IoU dips below the
/// match threshold and a naive tracker re-issues a new id every pan — which is
/// exactly what made the "Recoge este" highlight jump or stick to empty floor.
/// Instead we blend overlap, center proximity and size similarity into one
/// score, with the label as a soft factor, so the same toy holds its id under
/// motion while genuinely distinct toys stay separate.
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
    final matchedTracks = <int>{};

    // Score every plausible (track, detection) pair, then resolve greedily by
    // best score. A pair is only a candidate when it is spatially plausible
    // (some overlap OR centers within reach), the labels are compatible, and
    // the blended score clears the accept floor.
    final candidates = <_Match>[];
    for (var ti = 0; ti < _tracked.length; ti++) {
      final track = _tracked[ti];
      for (var di = 0; di < detections.length; di++) {
        final det = detections[di];
        final iou = _iou.iou(track.box, det.box);
        final centerDistance = _centerDistance(track.box, det.box);

        // Spatially implausible: no overlap AND centers too far apart. This
        // is what keeps two distinct toys from ever merging by size+label.
        if (iou <= 0 && centerDistance > config.trackMatchMaxCenterDistance) {
          continue;
        }
        // Label gate: same class, OR strong overlap (the detector relabelled
        // the same physical toy between frames — class flicker).
        if (track.label != det.label && iou < config.iouMatchThreshold) {
          continue;
        }

        final proximity =
            (1 - centerDistance / config.trackMatchMaxCenterDistance)
                .clamp(0.0, 1.0);
        final sizeSimilarity = _sizeSimilarity(track.box, det.box);
        final score = iou * 0.5 + proximity * 0.4 + sizeSimilarity * 0.1;
        if (score < config.trackMatchMinScore) continue;

        candidates.add(
          _Match(
            trackIndex: ti,
            detectionIndex: di,
            score: score,
            iou: iou,
          ),
        );
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final usedDetections = <int>{};
    for (final m in candidates) {
      if (matchedTracks.contains(m.trackIndex)) continue;
      if (usedDetections.contains(m.detectionIndex)) continue;
      matchedTracks.add(m.trackIndex);
      usedDetections.add(m.detectionIndex);

      final track = _tracked[m.trackIndex];
      final det = detections[m.detectionIndex];
      final wasMissing = track.framesMissing;
      track.box = det.box;
      track.confidence = det.confidence;
      track.label = det.label;
      track.displayName = det.displayName;
      track.framesSeen += 1;
      track.framesMissing = 0;
      if (kDebugMode) {
        final tag = wasMissing > 0 ? ' (re-matched after $wasMissing)' : '';
        debugPrint('[Tracker] Matched detection to existing toy: '
            'id=${_fmtId(track.id)} iou=${m.iou.toStringAsFixed(2)} '
            'score=${m.score.toStringAsFixed(2)}$tag');
      }
    }

    // Unmatched existing tracks age; drop those missing too long.
    for (var ti = 0; ti < _tracked.length; ti++) {
      if (!matchedTracks.contains(ti)) {
        _tracked[ti].framesMissing += 1;
      }
    }
    if (kDebugMode) {
      for (final t in _tracked) {
        if (t.framesMissing > config.maximumMissingFrames) {
          debugPrint('[Tracker] Dropped toy (missing too long): '
              'id=${_fmtId(t.id)} missedFrames=${t.framesMissing}');
        }
      }
    }
    _tracked.removeWhere(
      (t) => t.framesMissing > config.maximumMissingFrames,
    );

    // Unmatched detections become new tracked toys.
    for (var di = 0; di < detections.length; di++) {
      if (usedDetections.contains(di)) continue;
      final det = detections[di];
      final id = _nextId++;
      _tracked.add(
        TrackedToy(
          id: id,
          label: det.label,
          displayName: det.displayName,
          box: det.box,
          confidence: det.confidence,
        ),
      );
      if (kDebugMode) {
        debugPrint('[Tracker] Created tracked toy: '
            'id=${_fmtId(id)} label=${det.label}');
      }
    }

    return tracked;
  }

  /// Clear all tracked identities (used by the reset action).
  void reset() {
    _tracked.clear();
    _nextId = 0;
  }

  double _centerDistance(BoundingBox a, BoundingBox b) {
    final dx = a.centerX - b.centerX;
    final dy = a.centerY - b.centerY;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// 1.0 when two boxes are the same size, decaying toward 0 as their widths
  /// and heights diverge. A weak signal (weight 0.1) used only to break ties.
  double _sizeSimilarity(BoundingBox a, BoundingBox b) {
    if (a.width <= 0 || b.width <= 0 || a.height <= 0 || b.height <= 0) {
      return 0;
    }
    final widthRatio =
        a.width < b.width ? a.width / b.width : b.width / a.width;
    final heightRatio =
        a.height < b.height ? a.height / b.height : b.height / a.height;
    return (widthRatio * heightRatio).clamp(0.0, 1.0);
  }
}

/// Formats an integer track id as `toy_NNN` for human-readable logs.
String _fmtId(int id) => 'toy_${id.toString().padLeft(3, '0')}';

class _Match {
  const _Match({
    required this.trackIndex,
    required this.detectionIndex,
    required this.score,
    required this.iou,
  });

  final int trackIndex;
  final int detectionIndex;
  final double score;
  final double iou;
}
