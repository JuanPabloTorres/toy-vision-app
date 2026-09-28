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
    snapshotCreated |= result.initialSnapshot != null;
    if (armCleanup &&
        result.initialSnapshot != null &&
        cleanup.session == null) {
      cleanup.startCleanup(cameraFrame.timestamp);
    }
    sessionCreated |= cleanup.session != null;
    collected += result.events.whereType<ToyCollected>().length;
    completed += result.events.whereType<CleanupCompleted>().length;
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
  );
}

class _RunOutcome {
  const _RunOutcome({
    required this.collected,
    required this.completed,
    required this.sawUnconfirmedCandidates,
    required this.snapshotCreated,
    required this.sessionCreated,
  });

  final int collected;
  final int completed;
  final bool sawUnconfirmedCandidates;
  final bool snapshotCreated;
  final bool sessionCreated;
}
