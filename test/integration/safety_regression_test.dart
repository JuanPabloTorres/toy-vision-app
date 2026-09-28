import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';
import 'package:toyvision_realtime/perception/room_discovery/room_discovery_session.dart';

import '../support/camera_replay.dart';

void main() {
  group('conservative gameplay regressions', () {
    test('A/H/I: 60 seconds of non-semantic regions cannot progress', () async {
      final frames = [
        for (var index = 0; index <= 120; index++)
          ReplayFrame(
            milliseconds: index * 500,
            background: const [120, 125, 130],
            toy: index.isEven,
            detect: false,
            toyX: 0.1 + (index % 4) * 0.18,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
      expect(outcome.sessionCreated, isFalse);
      expect(outcome.sawUnconfirmedCandidates, isTrue);
    });

    test('C: covering the camera cannot collect or complete', () async {
      final frames = <ReplayFrame>[
        ..._stableToyFrames(),
        for (var index = 0; index < 12; index++)
          ReplayFrame(
            milliseconds: 3900 + index * 300,
            background: const [0, 0, 0],
            toy: false,
            detect: false,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(outcome.sessionCreated, isTrue);
      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
    });

    test('B: fast pickup between frames collects and completes', () async {
      final frames = <ReplayFrame>[
        ..._stableToyFrames(),
        for (var index = 0; index < 14; index++)
          ReplayFrame(
            milliseconds: 3900 + index * 300,
            background: const [150, 150, 150],
            toy: false,
            detect: false,
          ),
        for (var index = 0; index < 14; index++)
          ReplayFrame(
            milliseconds: 8100 + index * 300,
            background: const [90, 120, 165],
            toy: false,
            detect: false,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(outcome.sessionCreated, isTrue);
      expect(
        outcome.collected,
        1,
        reason: outcome.lastRemovalDiagnostic,
      );
      expect(
        outcome.firstCollectedAt!.difference(
          DateTime.utc(2026).add(const Duration(milliseconds: 3900)),
        ),
        lessThanOrEqualTo(const Duration(seconds: 3)),
      );
      expect(outcome.completed, 1);
      expect(outcome.firstCompletedAt, isNotNull);
    });

    test('B2: slight phone movement during pickup recovers and completes',
        () async {
      final frames = <ReplayFrame>[
        for (var index = 0; index < 13; index++)
          ReplayFrame(
            milliseconds: index * 300,
            background: const [150, 150, 150],
            toy: true,
            detect: true,
            gyroscopeRadPerSecond: 0.01,
            yawDegrees: 0,
            pitchDegrees: 55,
          ),
        const ReplayFrame(
          milliseconds: 3900,
          background: [150, 150, 150],
          toy: false,
          detect: false,
          gyroscopeRadPerSecond: 0.15,
          yawDegrees: 3,
          pitchDegrees: 55,
        ),
        for (var index = 0; index < 14; index++)
          ReplayFrame(
            milliseconds: 4200 + index * 300,
            background: const [150, 150, 150],
            toy: false,
            detect: false,
            gyroscopeRadPerSecond: 0.01,
            yawDegrees: 3,
            pitchDegrees: 55,
          ),
        for (var index = 0; index < 14; index++)
          ReplayFrame(
            milliseconds: 8400 + index * 300,
            background: const [90, 120, 165],
            toy: false,
            detect: false,
            gyroscopeRadPerSecond: 0.01,
            yawDegrees: 35,
            pitchDegrees: 55,
          ),
        for (var index = 0; index < 14; index++)
          ReplayFrame(
            milliseconds: 12600 + index * 300,
            background: const [165, 110, 80],
            toy: false,
            detect: false,
            gyroscopeRadPerSecond: 0.01,
            yawDegrees: -30,
            pitchDegrees: 55,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(
        outcome.collected,
        1,
        reason: outcome.lastRemovalDiagnostic,
      );
      expect(outcome.completed, 1);
    });

    test('D: a moving unknown region cannot become a confirmed toy', () async {
      final frames = [
        for (var index = 0; index < 30; index++)
          ReplayFrame(
            milliseconds: index * 200,
            background: const [145, 145, 145],
            toy: true,
            detect: true,
            toyX: 0.05 + index * 0.02,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(outcome.sessionCreated, isFalse);
      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
    });

    test('F: detector dropout while object remains cannot collect', () async {
      final frames = <ReplayFrame>[
        ..._stableToyFrames(),
        for (var index = 0; index < 24; index++)
          ReplayFrame(
            milliseconds: 3900 + index * 300,
            background: const [150, 150, 150],
            toy: true,
            detect: false,
          ),
      ];
      final outcome = await _run(frames, armCleanup: true);

      expect(outcome.sessionCreated, isTrue);
      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
    });

    test('E: disappear and reappear before removal is never collected',
        () async {
      final replay = CameraReplay.load(
        'test/fixtures/replays/cleanup_adverse.json',
      );
      final outcome = await _run(
        replay.frames.take(18).toList(),
        armCleanup: true,
      );

      expect(outcome.sessionCreated, isTrue);
      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
    });

    test('gameplay cannot progress before the explicit start action', () async {
      final replay = CameraReplay.load(
        'test/fixtures/replays/cleanup_adverse.json',
      );
      final outcome = await _run(replay.frames, armCleanup: false);

      expect(outcome.snapshotCreated, isTrue);
      expect(outcome.sessionCreated, isFalse);
      expect(outcome.collected, 0);
      expect(outcome.completed, 0);
    });
  });
}

List<ReplayFrame> _stableToyFrames() => [
      for (var index = 0; index < 13; index++)
        ReplayFrame(
          milliseconds: index * 300,
          background: const [150, 150, 150],
          toy: true,
          detect: true,
        ),
    ];

Future<_RunOutcome> _run(
  List<ReplayFrame> frames, {
  required bool armCleanup,
}) async {
  final renderer = CameraReplay(
    name: 'safety-regression',
    width: 320,
    height: 240,
    frames: frames,
  );
  final engine = HybridToyPerceptionEngine();
  final cleanup = CleanupSessionService(
    roomDiscovery: RoomDiscoverySession(
      policy: const RoomDiscoveryPolicy(
        minimumViewpoints: 1,
        minimumCameraMotion: 0,
      ),
    ),
  );
  final origin = DateTime.utc(2026);
  var collected = 0;
  var completed = 0;
  var sawUnconfirmedCandidates = false;
  var snapshotCreated = false;
  var sessionCreated = false;
  var lastRemovalDiagnostic = 'no disappearance evidence';
  DateTime? firstCollectedAt;
  DateTime? firstCompletedAt;

  for (var index = 0; index < frames.length; index++) {
    final cameraFrame = renderer.render(
      frames[index],
      frameId: index,
      origin: origin,
    );
    final perception = await engine.processFrame(
      cameraFrame,
      discoveryMode: cleanup.snapshot == null,
    );
    sawUnconfirmedCandidates |= perception.uncertainObservations.isNotEmpty;
    final result = cleanup.process(
      perception,
      allowCollection: cleanup.session != null,
    );
    for (final evidence in perception.disappearanceEvidence.values) {
      final track = perception.worldModel.missingTracks[evidence.trackId];
      lastRemovalDiagnostic =
          'frame=$index scene=${perception.worldModel.scene.state.name} '
          'motion=${perception.worldModel.scene.motion.toStringAsFixed(3)} '
          'anchor=${perception.worldModel.scene.similarityToStableAnchor.toStringAsFixed(3)} '
          'cameraLoss=${track?.lostDuringCameraMotion} '
          'lossMotion=${track?.cameraMotionAtLoss.toStringAsFixed(3)} '
          'direct=${evidence.directPickupEvidence} '
          'return=${evidence.returnToAnchorPickupEvidence} '
          'background=${evidence.backgroundRevealScore.toStringAsFixed(3)} '
          'local=${evidence.localSimilarity.toStringAsFixed(3)} '
          'reasons=${evidence.rejectionReasons.join(',')}';
    }
    snapshotCreated |= result.initialSnapshot != null;
    if (armCleanup &&
        result.initialSnapshot != null &&
        cleanup.session == null) {
      cleanup.startCleanup(cameraFrame.timestamp);
    }
    sessionCreated |= cleanup.session != null;
    collected += result.events.whereType<ToyCollected>().length;
    completed += result.events.whereType<CleanupCompleted>().length;
    for (final event in result.events) {
      if (event is ToyCollected) {
        firstCollectedAt ??= event.occurredAt;
      } else if (event is CleanupCompleted) {
        firstCompletedAt ??= event.occurredAt;
      }
    }
    for (final trackId in result.tracksToMarkCollected) {
      engine.markCollected(trackId, cameraFrame.timestamp);
    }
  }
  return _RunOutcome(
    collected: collected,
    completed: completed,
    sawUnconfirmedCandidates: sawUnconfirmedCandidates,
    snapshotCreated: snapshotCreated,
    sessionCreated: sessionCreated,
    lastRemovalDiagnostic: lastRemovalDiagnostic,
    firstCollectedAt: firstCollectedAt,
    firstCompletedAt: firstCompletedAt,
  );
}

class _RunOutcome {
  const _RunOutcome({
    required this.collected,
    required this.completed,
    required this.sawUnconfirmedCandidates,
    required this.snapshotCreated,
    required this.sessionCreated,
    required this.lastRemovalDiagnostic,
    required this.firstCollectedAt,
    required this.firstCompletedAt,
  });

  final int collected;
  final int completed;
  final bool sawUnconfirmedCandidates;
  final bool snapshotCreated;
  final bool sessionCreated;
  final String lastRemovalDiagnostic;
  final DateTime? firstCollectedAt;
  final DateTime? firstCompletedAt;
}
