import 'dart:math' as math;

import '../../core/math/vector_math.dart';
import '../perception_models.dart';

class CandidateTemporalEvidence {
  const CandidateTemporalEvidence({
    required this.persistence,
    required this.spatialStability,
  });

  final double persistence;
  final double spatialStability;
}

class CandidateTemporalMemory {
  final List<_CandidateMemory> _entries = [];

  List<CandidateTemporalEvidence> scoreAndUpdate(
    List<VisualCandidate> candidates,
    DateTime timestamp,
  ) {
    _entries.removeWhere(
      (entry) =>
          timestamp.difference(entry.lastSeen) > const Duration(seconds: 2),
    );
    final used = <int>{};
    final scores = <CandidateTemporalEvidence>[];
    final replacements = <_CandidateMemory>[];
    for (final candidate in candidates) {
      var bestIndex = -1;
      var bestScore = 0.0;
      for (var index = 0; index < _entries.length; index++) {
        if (used.contains(index)) continue;
        final previous = _entries[index];
        final embedding = cosineSimilarity(
          candidate.embedding,
          previous.candidate.embedding,
        ).clamp(0.0, 1.0);
        final score = candidate.bounds.intersectionOverUnion(
                  previous.candidate.bounds,
                ) *
                0.35 +
            candidate.bounds.centroidSimilarity(previous.candidate.bounds) *
                0.20 +
            embedding * 0.45;
        if (score > bestScore) {
          bestScore = score;
          bestIndex = index;
        }
      }
      if (bestIndex >= 0 && bestScore >= 0.48) {
        used.add(bestIndex);
        final previous = _entries[bestIndex];
        final sightings = previous.sightings + 1;
        final previousBounds = previous.candidate.bounds;
        final dx = candidate.bounds.centerX - previousBounds.centerX;
        final dy = candidate.bounds.centerY - previousBounds.centerY;
        final displacement = math.sqrt(dx * dx + dy * dy);
        final sizeStability = candidate.bounds.sizeSimilarity(previousBounds);
        // Detector boxes jitter by several pixels even while the phone and
        // object are still. Scale tolerance with the smaller object box so a
        // small cleanup item is not permanently denied persistence.
        final objectScale = math.min(
          math.min(candidate.bounds.width, candidate.bounds.height),
          math.min(previousBounds.width, previousBounds.height),
        );
        final allowedDisplacement = (objectScale * 0.20).clamp(0.015, 0.019);
        final isStationary =
            displacement <= allowedDisplacement && sizeStability >= 0.75;
        final stationarySightings =
            isStationary ? previous.stationarySightings + 1 : 1;
        replacements.add(
          _CandidateMemory(
            candidate,
            sightings,
            timestamp,
            stationarySightings,
          ),
        );
        // Stability describes the current observation window. Comparing with
        // the first-ever box permanently poisoned a candidate after a camera
        // pan, even once both camera and object had become still again.
        final positionStability =
            (1 - displacement / (allowedDisplacement * 5)).clamp(0.0, 1.0);
        final normalizedSizeStability =
            ((sizeStability - 0.5) / 0.5).clamp(0.0, 1.0);
        scores.add(
          CandidateTemporalEvidence(
            persistence: math.min(1.0, sightings / 3),
            spatialStability: math.min(
              math.min(positionStability, normalizedSizeStability),
              stationarySightings / 3,
            ),
          ),
        );
      } else {
        replacements.add(
          _CandidateMemory(candidate, 1, timestamp, 1),
        );
        scores.add(
          const CandidateTemporalEvidence(
            persistence: 1 / 3,
            spatialStability: 1 / 3,
          ),
        );
      }
    }
    for (final index in used.toList()..sort((a, b) => b.compareTo(a))) {
      _entries.removeAt(index);
    }
    _entries.addAll(replacements);
    return scores;
  }

  void clear() => _entries.clear();
}

class _CandidateMemory {
  const _CandidateMemory(
    this.candidate,
    this.sightings,
    this.lastSeen,
    this.stationarySightings,
  );
  final VisualCandidate candidate;
  final int sightings;
  final DateTime lastSeen;
  final int stationarySightings;
}
