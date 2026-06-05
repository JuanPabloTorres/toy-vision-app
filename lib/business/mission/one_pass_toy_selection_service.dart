import 'dart:math' as math;

import '../../detection/models/bounding_box.dart';

/// One scorable toy the selector may lock onto, distilled from a tracked toy.
class ToySelectionCandidate {
  const ToySelectionCandidate({
    required this.id,
    required this.confidence,
    required this.box,
    this.framesSeen = 1,
  });

  /// Stable tracker id — the identity that gets locked.
  final int id;
  final double confidence;
  final BoundingBox box;

  /// How many frames this toy has persisted (stability term, spec #6.4).
  final int framesSeen;
}

/// Why a candidate was (or was not) chosen — surfaced in the `[TARGET_SELECT]`
/// log so the on-device run can confirm selection happened in the same pass.
enum ToySelectionReason {
  /// No eligible candidate this frame.
  none,

  /// Picked the highest-scoring toy: confidence first, center proximity breaks
  /// ties (spec #6.1–6.2).
  highestConfidenceClosestToCenter,
}

/// The single decision the selector returns for one snapshot.
class ToySelectionDecision {
  const ToySelectionDecision(this.selectedId, this.reason);

  final int? selectedId;
  final ToySelectionReason reason;

  bool get hasSelection => selectedId != null;

  static const ToySelectionDecision none =
      ToySelectionDecision(null, ToySelectionReason.none);
}

/// Picks the single best toy to lock onto **from one frame's candidates** — the
/// "selección" half of the one-pass detect+select cycle.
///
/// It does NOT decide whether to switch off an existing target: the caller only
/// invokes this when there is no active target (the hard lock lives in the
/// controller). Given a fresh set of visible candidates it applies the spec's
/// scoring priority:
///
///   1. higher confidence            (dominant term)
///   2. closer to the frame center   (tie-breaker)
///   3. box big enough               (eligibility floor)
///   4. stable for a few frames      (eligibility floor)
///   5/6. valid box, not collected   (caller pre-filters collected)
///
/// Pure and synchronous — no controller state, no side effects — so the
/// scoring is unit-testable in isolation and cheap to run every frame.
class OnePassToySelectionService {
  const OnePassToySelectionService({
    this.minBoxAreaFraction = 0.0,
    this.minStableFrames = 1,
  });

  /// Reject candidates whose box covers less than this fraction of the frame
  /// (spec #6.3 / "no detecciones demasiado pequeñas"). 0 = no size floor.
  final double minBoxAreaFraction;

  /// Reject candidates seen on fewer than this many frames (spec #6.4).
  final int minStableFrames;

  /// The best toy to lock onto, or [ToySelectionDecision.none] when nothing is
  /// eligible. Confidence dominates; center proximity only separates near-ties
  /// (a 0.25 confidence gap can never be overturned by position).
  ToySelectionDecision selectBest(Iterable<ToySelectionCandidate> candidates) {
    ToySelectionCandidate? best;
    var bestScore = double.negativeInfinity;
    for (final candidate in candidates) {
      if (!_isEligible(candidate)) continue;
      final score = _score(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    if (best == null) return ToySelectionDecision.none;
    return ToySelectionDecision(
      best.id,
      ToySelectionReason.highestConfidenceClosestToCenter,
    );
  }

  bool _isEligible(ToySelectionCandidate candidate) {
    if (candidate.framesSeen < minStableFrames) return false;
    if (!candidate.box.isValid) return false;
    if (candidate.box.area < minBoxAreaFraction) return false;
    return true;
  }

  double _score(ToySelectionCandidate candidate) {
    final dx = candidate.box.centerX - 0.5;
    final dy = candidate.box.centerY - 0.5;
    final distance = math.sqrt(dx * dx + dy * dy); // 0 .. ~0.707
    final centerScore = (1 - distance / _maxCenterDistance).clamp(0.0, 1.0);
    // Confidence (0..1) dominates; the center term is scaled so it only ever
    // breaks ties between similarly-confident toys.
    return candidate.confidence + centerScore * _centerWeight;
  }

  /// Half the frame diagonal — the largest a center distance can be.
  static const double _maxCenterDistance = 0.7071;
  static const double _centerWeight = 0.25;
}
