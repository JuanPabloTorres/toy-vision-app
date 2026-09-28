import 'dart:math' as math;

import '../../core/math/vector_math.dart';
import '../../domain/scene/room_snapshot.dart';
import '../../domain/scene/room_world_model.dart';

class RoomDiscoveryPolicy {
  const RoomDiscoveryPolicy({
    this.minimumDuration = const Duration(seconds: 3),
    this.quietPeriod = const Duration(seconds: 1),
    this.minimumStableToys = 1,
    this.minimumViewpoints = 2,
    this.minimumCameraMotion = 0.08,
    this.viewpointSimilarityThreshold = 0.92,
  });

  final Duration minimumDuration;
  final Duration quietPeriod;
  final int minimumStableToys;
  final int minimumViewpoints;
  final double minimumCameraMotion;
  final double viewpointSimilarityThreshold;
}

class RoomDiscoveryProgress {
  const RoomDiscoveryProgress({
    required this.stableToyCount,
    required this.viewpointCount,
    required this.cameraMotion,
    required this.coverageEstimate,
    required this.complete,
  });

  const RoomDiscoveryProgress.empty()
      : stableToyCount = 0,
        viewpointCount = 0,
        cameraMotion = 0,
        coverageEstimate = 0,
        complete = false;

  final int stableToyCount;
  final int viewpointCount;
  final double cameraMotion;
  final double coverageEstimate;
  final bool complete;
}

/// Accumulates room-level discovery evidence across camera viewpoints.
///
/// A single stable frame is deliberately insufficient. Completion requires a
/// non-empty stable toy inventory, deliberate camera movement, more than one
/// distinct viewpoint, a quiet period without new toys, and a stable final
/// view. This class records evidence only; it never starts gameplay or emits
/// collection events.
class RoomDiscoverySession {
  RoomDiscoverySession({
    this.policy = const RoomDiscoveryPolicy(),
  });

  final RoomDiscoveryPolicy policy;

  DateTime? _startedAt;
  DateTime? _lastNewToyAt;
  List<double>? _previousSceneEmbedding;
  final List<List<double>> _viewpoints = [];
  final Map<int, ToyTrackSnapshot> _stableToys = {};
  double _cameraMotion = 0;
  RoomDiscoveryProgress _progress = const RoomDiscoveryProgress.empty();

  RoomDiscoveryProgress get progress => _progress;

  RoomDiscoveryProgress observe(RoomWorldModel world) {
    final now = world.updatedAt;
    _startedAt ??= now;

    final previous = _previousSceneEmbedding;
    if (previous != null) {
      final stepMotion =
          (1 - cosineSimilarity(previous, world.scene.embedding)).clamp(0, 1);
      // Very large jumps are covers/cuts, not useful camera sweep evidence.
      if (stepMotion <= 0.65) {
        _cameraMotion += stepMotion;
      }
    }
    _previousSceneEmbedding = world.scene.embedding;

    if (world.scene.embedding.isNotEmpty &&
        _viewpoints.every(
          (viewpoint) =>
              cosineSimilarity(viewpoint, world.scene.embedding) <
              policy.viewpointSimilarityThreshold,
        )) {
      _viewpoints.add(List<double>.from(world.scene.embedding));
    }

    var foundNewToy = false;
    for (final track
        in world.activeTracks.values.where((track) => track.isStable)) {
      if (!_stableToys.containsKey(track.id)) foundNewToy = true;
      _stableToys[track.id] = ToyTrackSnapshot.fromTrack(track);
    }
    if (foundNewToy) _lastNewToyAt = now;

    final elapsed = now.difference(_startedAt!);
    final quietFor = now.difference(_lastNewToyAt ?? _startedAt!);
    final viewpointCoverage = policy.minimumViewpoints <= 0
        ? 1.0
        : (_viewpoints.length / policy.minimumViewpoints).clamp(0.0, 1.0);
    final motionCoverage = policy.minimumCameraMotion <= 0
        ? 1.0
        : (_cameraMotion / policy.minimumCameraMotion).clamp(0.0, 1.0);
    final coverage = math.min(viewpointCoverage, motionCoverage);
    final complete = elapsed >= policy.minimumDuration &&
        quietFor >= policy.quietPeriod &&
        _stableToys.length >= policy.minimumStableToys &&
        _viewpoints.length >= policy.minimumViewpoints &&
        _cameraMotion >= policy.minimumCameraMotion &&
        world.scene.canVerifyDisappearance;

    _progress = RoomDiscoveryProgress(
      stableToyCount: _stableToys.length,
      viewpointCount: _viewpoints.length,
      cameraMotion: _cameraMotion,
      coverageEstimate: coverage,
      complete: complete,
    );
    return _progress;
  }

  RoomSnapshot? createSnapshot(RoomWorldModel world) {
    final progress = observe(world);
    if (!progress.complete || _stableToys.isEmpty) return null;
    final toys = _stableToys.values.toList(growable: false);
    final averageConfidence = toys.fold<double>(
          0,
          (sum, toy) => sum + toy.confidence,
        ) /
        toys.length;
    return RoomSnapshot(
      id: 'room_${world.updatedAt.microsecondsSinceEpoch}',
      createdAt: world.updatedAt,
      toys: toys,
      sceneEmbedding: world.scene.embedding,
      geometry: SceneGeometry(
        coverage: progress.coverageEstimate,
        anchorCount: toys.length,
      ),
      confidence: averageConfidence,
    );
  }

  void reset() {
    _startedAt = null;
    _lastNewToyAt = null;
    _previousSceneEmbedding = null;
    _viewpoints.clear();
    _stableToys.clear();
    _cameraMotion = 0;
    _progress = const RoomDiscoveryProgress.empty();
  }
}
