import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/scene/room_snapshot.dart';
import '../../domain/scene/room_world_model.dart';
import '../../perception/coverage/room_coverage_tracker.dart';

enum CompletionConfidence { insufficient, probable, strong }

enum RoomCleanDecision {
  toyFound,
  needMoreCoverage,
  roomClean,
}

enum RoomVerificationStage {
  waitingForPickups,
  surveyingRoom,
  confirmingEmpty,
  complete,
}

class RoomCleanPolicy {
  const RoomCleanPolicy({
    this.minimumCleanDuration = const Duration(seconds: 2),
    this.minimumCleanFrames = 5,
    this.minimumVisualViewpoints = 2,
    this.viewpointSimilarityThreshold = 0.92,
    this.minimumHorizontalRegions = 3,
    this.maximumStableObservationGap = const Duration(milliseconds: 1200),
  });

  final Duration minimumCleanDuration;
  final int minimumCleanFrames;
  final int minimumVisualViewpoints;
  final double viewpointSimilarityThreshold;
  final int minimumHorizontalRegions;
  final Duration maximumStableObservationGap;
}

class CompletionEvidence {
  CompletionEvidence({
    required this.confidence,
    required this.collectedRatio,
    required this.remainingStableToys,
    required this.sceneCoverage,
    required this.uncertainTracks,
    required List<String> blockingReasons,
    this.cleanDecision = RoomCleanDecision.needMoreCoverage,
    this.guidance = 'Miremos alrededor una vez más.',
    this.coverageSectors = const [],
    this.confirmedToyCount = 0,
    this.candidateToyCount = 0,
    this.noToyDuration = Duration.zero,
    this.sceneStable = false,
    this.cameraTrackingGood = false,
    this.depthConsistency,
    this.verificationStage = RoomVerificationStage.waitingForPickups,
  }) : blockingReasons = List<String>.unmodifiable(blockingReasons);

  final CompletionConfidence confidence;
  final double collectedRatio;
  final int remainingStableToys;
  final double sceneCoverage;
  final int uncertainTracks;
  final List<String> blockingReasons;
  final RoomCleanDecision cleanDecision;
  final String guidance;
  final List<String> coverageSectors;
  final int confirmedToyCount;
  final int candidateToyCount;
  final Duration noToyDuration;
  final bool sceneStable;
  final bool cameraTrackingGood;
  final double? depthConsistency;
  final RoomVerificationStage verificationStage;
}

class RoomCleanEvaluation {
  const RoomCleanEvaluation({
    required this.decision,
    required this.evidence,
    required this.verifying,
    required this.verificationStarted,
  });

  final RoomCleanDecision decision;
  final CompletionEvidence evidence;
  final bool verifying;
  final bool verificationStarted;
}

abstract interface class RoomCleanVerifier {
  RoomCleanEvaluation evaluate({
    required RoomSnapshot snapshot,
    required RoomWorldModel world,
    required CleanupSession session,
    required int uncertainTracks,
  });

  void reset();
}

/// Verifies room cleanliness across time and more than one camera viewpoint.
///
/// The verifier only returns evidence and a decision. It cannot mutate the
/// cleanup session or publish completion events.
class EvidenceBasedRoomCleanVerifier implements RoomCleanVerifier {
  EvidenceBasedRoomCleanVerifier({
    this.policy = const RoomCleanPolicy(),
  }) : _coverageTracker = RoomCoverageTracker(
          minimumHorizontalRegions: policy.minimumHorizontalRegions,
          minimumVisualViewpoints: policy.minimumVisualViewpoints,
          viewpointSimilarityThreshold: policy.viewpointSimilarityThreshold,
        );

  final RoomCleanPolicy policy;

  RoomVerificationStage _stage = RoomVerificationStage.waitingForPickups;
  DateTime? _lastStableEmptyAt;
  Duration _stableEmptyDuration = Duration.zero;
  final RoomCoverageTracker _coverageTracker;
  int _cleanFrames = 0;

  @override
  RoomCleanEvaluation evaluate({
    required RoomSnapshot snapshot,
    required RoomWorldModel world,
    required CleanupSession session,
    required int uncertainTracks,
  }) {
    final total = snapshot.toys.length;
    final initialIds = snapshot.toys.map((toy) => toy.trackId).toSet();
    final remainingStable = world.activeTracks.values
        .where(
          (track) =>
              initialIds.contains(track.id) &&
              track.isStable &&
              !session.collectedTrackIds.contains(track.id),
        )
        .length;
    final unresolved = world.missingTracks.values.where(
      (track) =>
          initialIds.contains(track.id) &&
          !session.collectedTrackIds.contains(track.id),
    );
    final ratio = total == 0 ? 0.0 : session.confirmedCollected / total;
    final snapshotEstablished = total > 0 &&
        snapshot.confidence >= 0.68 &&
        snapshot.geometry.anchorCount == total &&
        snapshot.toys.every((toy) => toy.confidence >= 0.68);
    final allCollected = total > 0 &&
        session.confirmedCollected == total &&
        initialIds.difference(session.collectedTrackIds).isEmpty;
    final toyPresent = session.remainingEstimate > 0 || remainingStable > 0;
    final wasVerifying = _stage != RoomVerificationStage.waitingForPickups;

    if (toyPresent || !allCollected) {
      reset();
      final blockers = <String>[
        if (total == 0) 'initial_snapshot_empty',
        if (!snapshotEstablished) 'initial_snapshot_not_established',
        if (session.confirmedCollected == 0) 'no_verified_progress',
        if (!allCollected) 'not_all_snapshot_toys_collected',
        if (remainingStable > 0) 'confirmed_toys_still_visible',
        if (unresolved.isNotEmpty) 'ambiguous_snapshot_tracks',
      ];
      return RoomCleanEvaluation(
        decision: wasVerifying && toyPresent
            ? RoomCleanDecision.toyFound
            : RoomCleanDecision.needMoreCoverage,
        evidence: CompletionEvidence(
          confidence: snapshotEstablished && ratio >= 0.7
              ? CompletionConfidence.probable
              : CompletionConfidence.insufficient,
          collectedRatio: ratio,
          remainingStableToys: remainingStable,
          sceneCoverage: 0,
          uncertainTracks: uncertainTracks,
          blockingReasons: blockers,
          cleanDecision: wasVerifying && toyPresent
              ? RoomCleanDecision.toyFound
              : RoomCleanDecision.needMoreCoverage,
          guidance: toyPresent
              ? '¡Encontré otro juguete! Vamos a recogerlo.'
              : 'Necesito una recogida confirmada antes de revisar el cuarto.',
          confirmedToyCount: remainingStable,
          candidateToyCount: uncertainTracks,
          sceneStable: world.scene.canVerifyDisappearance,
          cameraTrackingGood: world.scene.spatial.cameraTrackingGood,
          depthConsistency: world.scene.spatial.depthConsistency,
          verificationStage: RoomVerificationStage.waitingForPickups,
        ),
        verifying: false,
        verificationStarted: false,
      );
    }

    final verificationStarted =
        _stage == RoomVerificationStage.waitingForPickups;
    final coverageSnapshot = _coverageTracker.observe(world.scene);

    final sceneStable = world.scene.canVerifyDisappearance;
    final cameraTrackingGood = world.scene.spatial.cameraTrackingGood;
    _observeEmptyFrame(
      at: world.updatedAt,
      stable: uncertainTracks == 0 && sceneStable && cameraTrackingGood,
      candidatePresent: uncertainTracks > 0,
    );

    final coverage = coverageSnapshot.coverage;
    final cleanDuration = _stableEmptyDuration;
    final cleanWindowComplete = cleanDuration >= policy.minimumCleanDuration &&
        _cleanFrames >= policy.minimumCleanFrames;
    final coverageComplete = coverage >= 1;
    _stage = coverageComplete
        ? RoomVerificationStage.confirmingEmpty
        : RoomVerificationStage.surveyingRoom;
    final blockers = <String>[
      if (!snapshotEstablished) 'initial_snapshot_not_established',
      if (session.confirmedCollected == 0) 'no_verified_progress',
      if (!allCollected) 'not_all_snapshot_toys_collected',
      if (remainingStable > 0) 'confirmed_toys_still_visible',
      if (unresolved.isNotEmpty) 'ambiguous_snapshot_tracks',
      if (uncertainTracks > 0) 'ambiguous_toy_candidates',
      if (!sceneStable) 'scene_not_stable',
      if (!cameraTrackingGood) 'camera_tracking_not_reliable',
      if (!coverageComplete) 'room_coverage_incomplete',
      if (!cleanWindowComplete) 'clean_window_incomplete',
    ];
    final clean = blockers.isEmpty;
    if (clean) _stage = RoomVerificationStage.complete;
    final decision = clean
        ? RoomCleanDecision.roomClean
        : RoomCleanDecision.needMoreCoverage;
    return RoomCleanEvaluation(
      decision: decision,
      evidence: CompletionEvidence(
        confidence:
            clean ? CompletionConfidence.strong : CompletionConfidence.probable,
        collectedRatio: ratio,
        remainingStableToys: remainingStable,
        sceneCoverage: coverage,
        uncertainTracks: uncertainTracks,
        blockingReasons: blockers,
        cleanDecision: decision,
        guidance: _guidanceFor(coverageSnapshot, blockers),
        coverageSectors:
            coverageSnapshot.visited.map((sector) => sector.name).toList(),
        confirmedToyCount: remainingStable,
        candidateToyCount: uncertainTracks,
        noToyDuration: cleanDuration,
        sceneStable: sceneStable,
        cameraTrackingGood: cameraTrackingGood,
        depthConsistency: world.scene.spatial.depthConsistency,
        verificationStage: _stage,
      ),
      verifying: !clean,
      verificationStarted: verificationStarted,
    );
  }

  String _guidanceFor(
    RoomCoverageSnapshot coverage,
    List<String> blockers,
  ) {
    if (blockers.contains('ambiguous_toy_candidates')) {
      return 'Espera un momento: Tobi está comprobando algo que vio.';
    }
    if (coverage.coverage >= 1) {
      return '¡Se ve limpio! Mantén la cámara quieta un momento.';
    }
    return switch (coverage.nextRequired) {
      RoomCoverageSector.left =>
        'Mira despacio hacia la izquierda y detente un momento.',
      RoomCoverageSector.center =>
        'Mira el centro del cuarto y detente un momento.',
      RoomCoverageSector.right =>
        'Mira despacio hacia la derecha y detente un momento.',
      RoomCoverageSector.floorLeft => 'Miremos el piso a la izquierda.',
      RoomCoverageSector.floorCenter => 'Bajemos la cámara para mirar el piso.',
      RoomCoverageSector.floorRight => 'Miremos el piso a la derecha.',
      null => blockers.contains('scene_not_stable') ||
              blockers.contains('camera_tracking_not_reliable')
          ? 'Detén la cámara un momento para comprobar esta zona.'
          : 'Mueve la cámara despacio y detente en otra parte del cuarto.',
    };
  }

  void _observeEmptyFrame({
    required DateTime at,
    required bool stable,
    required bool candidatePresent,
  }) {
    if (candidatePresent) {
      _resetEmptyWindow();
      return;
    }
    if (!stable) {
      final lastStable = _lastStableEmptyAt;
      if (lastStable != null &&
          at.difference(lastStable) > policy.maximumStableObservationGap) {
        _resetEmptyWindow();
      }
      return;
    }

    final previousStable = _lastStableEmptyAt;
    if (previousStable == null ||
        at.difference(previousStable) > policy.maximumStableObservationGap) {
      _stableEmptyDuration = Duration.zero;
      _cleanFrames = 1;
    } else {
      _stableEmptyDuration += at.difference(previousStable);
      _cleanFrames += 1;
    }
    _lastStableEmptyAt = at;
  }

  void _resetEmptyWindow() {
    _lastStableEmptyAt = null;
    _stableEmptyDuration = Duration.zero;
    _cleanFrames = 0;
  }

  @override
  void reset() {
    _stage = RoomVerificationStage.waitingForPickups;
    _coverageTracker.reset();
    _resetEmptyWindow();
  }
}
