import '../../domain/cleanup/cleanup_event.dart';
import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/cleanup/collected_object_memory.dart';
import '../../domain/scene/room_snapshot.dart';
import '../../domain/toy/toy_observation.dart';
import '../../perception/perception_models.dart';
import '../../perception/room_discovery/room_discovery_session.dart';
import 'room_clean_verifier.dart';

class CleanupProcessingOutcome {
  CleanupProcessingOutcome({
    required this.session,
    required this.initialSnapshot,
    required List<CleanupEvent> events,
    required List<int> tracksToMarkCollected,
    required this.completionEvidence,
    required this.verifyingRoom,
    required this.discoveryProgress,
  })  : events = List.unmodifiable(events),
        tracksToMarkCollected = List.unmodifiable(tracksToMarkCollected);

  final CleanupSession? session;
  final RoomSnapshot? initialSnapshot;
  final List<CleanupEvent> events;
  final List<int> tracksToMarkCollected;
  final CompletionEvidence? completionEvidence;
  final bool verifyingRoom;
  final RoomDiscoveryProgress discoveryProgress;
}

class CleanupSessionService {
  CleanupSessionService({
    RoomDiscoverySession? roomDiscovery,
    RoomCleanVerifier? roomCleanVerifier,
    CollectedObjectMemory? collectedMemory,
  })  : _roomCleanVerifier =
            roomCleanVerifier ?? EvidenceBasedRoomCleanVerifier(),
        _collectedMemory = collectedMemory ?? CollectedObjectMemory(),
        _roomDiscovery = roomDiscovery ?? RoomDiscoverySession();

  final RoomCleanVerifier _roomCleanVerifier;
  final CollectedObjectMemory _collectedMemory;
  final RoomDiscoverySession _roomDiscovery;

  CleanupSession? _session;
  RoomSnapshot? _snapshot;
  bool _almostCleanPublished = false;

  CleanupSession? get session => _session;
  RoomSnapshot? get snapshot => _snapshot;

  CleanupProcessingOutcome process(
    PerceptionResult perception, {
    bool allowCollection = false,
  }) {
    final events = _transitionEvents(perception);
    if (_session == null) {
      _tryCreateInitialSnapshot(perception);
      return CleanupProcessingOutcome(
        session: _session,
        initialSnapshot: _snapshot,
        events: events,
        tracksToMarkCollected: const [],
        completionEvidence: null,
        verifyingRoom: false,
        discoveryProgress: _roomDiscovery.progress,
      );
    }

    var session = _session!;
    if (!allowCollection || session.status != CleanupStatus.active) {
      return CleanupProcessingOutcome(
        session: session,
        initialSnapshot: _snapshot,
        events: events,
        tracksToMarkCollected: const [],
        completionEvidence: null,
        verifyingRoom: false,
        discoveryProgress: _roomDiscovery.progress,
      );
    }

    for (final track in perception.worldModel.activeTracks.values) {
      final knownIds = _snapshot!.toys.map((toy) => toy.trackId).toSet();
      if (!track.isStable || knownIds.contains(track.id)) continue;
      if (_collectedMemory.probablyAlreadyCollected(
        trackId: track.id,
        embedding: track.visualEmbedding,
        bounds: track.lastBounds,
        timestamp: perception.worldModel.updatedAt,
      )) {
        continue;
      }
      _snapshot = _snapshot!.withToy(ToyTrackSnapshot.fromTrack(track));
      session = session.withExpandedSnapshot(_snapshot!);
      events.add(NewToyDiscovered(perception.worldModel.updatedAt, track.id));
      events.add(
        CleanupProgressChanged(
          perception.worldModel.updatedAt,
          collected: session.confirmedCollected,
          remainingEstimate: session.remainingEstimate,
        ),
      );
    }
    _session = session;
    final initialIds = _snapshot!.toys.map((toy) => toy.trackId).toSet();
    final markCollected = <int>[];
    for (final entry in perception.disappearanceEvidence.entries) {
      final evidence = entry.value;
      if (!evidence.confirmed || !initialIds.contains(entry.key)) continue;
      final track = perception.worldModel.missingTracks[entry.key];
      if (track == null ||
          session.collectedTrackIds.contains(entry.key) ||
          _collectedMemory.probablyAlreadyCollected(
            trackId: track.id,
            embedding: track.visualEmbedding,
            bounds: track.lastBounds,
            timestamp: perception.worldModel.updatedAt,
          )) {
        continue;
      }
      session = session.collect(track.id);
      _collectedMemory.remember(
        CollectedToySignature(
          trackId: track.id,
          embedding: track.visualEmbedding,
          recordedAt: perception.worldModel.updatedAt,
          lastBounds: track.lastBounds,
        ),
      );
      markCollected.add(track.id);
      events.add(ToyCollected(perception.worldModel.updatedAt, track.id));
      events.add(
        CleanupProgressChanged(
          perception.worldModel.updatedAt,
          collected: session.confirmedCollected,
          remainingEstimate: session.remainingEstimate,
        ),
      );
    }
    _session = session;
    final roomClean = _roomCleanVerifier.evaluate(
      snapshot: _snapshot!,
      world: perception.worldModel,
      session: session,
      uncertainTracks: perception.uncertainObservations
          .where(
            (candidate) =>
                candidate.source == ObservationSource.detector &&
                candidate.temporalPersistence >= 1,
          )
          .length,
    );
    final completion = roomClean.evidence;
    if (!_almostCleanPublished &&
        completion.collectedRatio >= 0.7 &&
        completion.confidence != CompletionConfidence.strong) {
      _almostCleanPublished = true;
      events.add(RoomAlmostClean(perception.worldModel.updatedAt));
    }
    if (roomClean.verificationStarted) {
      events.add(EmptyRoomVerificationStarted(perception.worldModel.updatedAt));
    }
    if (roomClean.decision == RoomCleanDecision.roomClean &&
        session.status == CleanupStatus.active) {
      session = session.complete(perception.worldModel.updatedAt);
      _session = session;
      events.add(RoomCleanConfirmed(perception.worldModel.updatedAt));
      events.add(
        CleanupCompleted(
          perception.worldModel.updatedAt,
          session.confirmedCollected,
        ),
      );
    }
    return CleanupProcessingOutcome(
      session: session,
      initialSnapshot: _snapshot,
      events: events,
      tracksToMarkCollected: markCollected,
      completionEvidence: completion,
      verifyingRoom:
          roomClean.verifying && session.status == CleanupStatus.active,
      discoveryProgress: _roomDiscovery.progress,
    );
  }

  void _tryCreateInitialSnapshot(PerceptionResult perception) {
    _snapshot ??= _roomDiscovery.createSnapshot(perception.worldModel);
  }

  CleanupSession? startCleanup(DateTime timestamp) {
    final snapshot = _snapshot;
    if (_session != null || snapshot == null || snapshot.toys.isEmpty) {
      return _session;
    }
    _session = CleanupSession.start(
      id: 'cleanup_${timestamp.microsecondsSinceEpoch}',
      snapshot: snapshot,
      startedAt: timestamp,
    );
    return _session;
  }

  List<CleanupEvent> _transitionEvents(PerceptionResult perception) {
    final at = perception.worldModel.updatedAt;
    return perception.transitions.map((transition) {
      return switch (transition.type) {
        TrackTransitionType.created => ToyTrackCreated(at, transition.trackId),
        TrackTransitionType.observed => ToyObserved(at, transition.trackId),
        TrackTransitionType.temporarilyMissing =>
          ToyTemporarilyMissing(at, transition.trackId),
        TrackTransitionType.reappeared => ToyReappeared(at, transition.trackId),
      };
    }).toList();
  }

  void reset() {
    _session = null;
    _snapshot = null;
    _almostCleanPublished = false;
    _collectedMemory.clear();
    _roomDiscovery.reset();
    _roomCleanVerifier.reset();
  }
}
