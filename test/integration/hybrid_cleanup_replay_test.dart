import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/application/cleanup/room_clean_verifier.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_session.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';
import 'package:toyvision_realtime/perception/room_discovery/room_discovery_session.dart';

import '../support/camera_replay.dart';

void main() {
  test('adverse camera replay completes once without pan false positives',
      () async {
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine();
    final sessions = CleanupSessionService(
      roomDiscovery: RoomDiscoverySession(
        policy: const RoomDiscoveryPolicy(
          minimumViewpoints: 1,
          minimumCameraMotion: 0,
        ),
      ),
      roomCleanVerifier: EvidenceBasedRoomCleanVerifier(
        policy: const RoomCleanPolicy(
          minimumCleanDuration: Duration(seconds: 2),
          minimumCleanFrames: 3,
          minimumViewpoints: 1,
          minimumCameraMotion: 0,
        ),
      ),
    );
    final origin = DateTime.utc(2026, 1, 1);
    var collectedEvents = 0;
    var roomCleanEvents = 0;
    var completedEvents = 0;
    var collectedBeforeReappearance = false;
    var sawSessionBeforePan = false;
    DateTime? verificationStartedAt;
    DateTime? completedAt;
    final disappearanceTimeline = <String>[];

    for (var index = 0; index < replay.frames.length; index++) {
      final frame = replay.frames[index];
      final cameraFrame = replay.render(
        frame,
        frameId: index,
        origin: origin,
      );
      final perception = await engine.processFrame(
        cameraFrame,
        discoveryMode: sessions.snapshot == null,
      );
      final outcome = sessions.process(
        perception,
        allowCollection: sessions.session != null,
      );
      for (final evidence in perception.disappearanceEvidence.values) {
        disappearanceTimeline.add(
          '${frame.milliseconds}ms track ${evidence.trackId}: '
          '${evidence.rejectionReasons.join(',')}',
        );
      }
      if (outcome.initialSnapshot != null && sessions.session == null) {
        sessions.startCleanup(cameraFrame.timestamp);
      }
      sawSessionBeforePan |=
          frame.milliseconds < 3900 && outcome.session != null;
      if (frame.milliseconds <= 5100 &&
          outcome.events.any((event) => event is ToyCollected)) {
        collectedBeforeReappearance = true;
      }
      collectedEvents += outcome.events.whereType<ToyCollected>().length;
      roomCleanEvents += outcome.events.whereType<RoomCleanConfirmed>().length;
      completedEvents += outcome.events.whereType<CleanupCompleted>().length;
      if (outcome.events
          .any((event) => event is EmptyRoomVerificationStarted)) {
        verificationStartedAt = cameraFrame.timestamp;
      }
      if (outcome.events.any((event) => event is CleanupCompleted)) {
        completedAt = cameraFrame.timestamp;
      }
      for (final trackId in outcome.tracksToMarkCollected) {
        engine.markCollected(trackId, cameraFrame.timestamp);
      }
    }

    expect(
      sawSessionBeforePan,
      isTrue,
      reason: 'initial scan must freeze first',
    );
    expect(
      collectedBeforeReappearance,
      isFalse,
      reason: 'turning the camera away cannot collect the toy',
    );
    expect(
      collectedEvents,
      1,
      reason: 'one physical toy may count only once\n'
          '${disappearanceTimeline.skip((disappearanceTimeline.length - 12).clamp(0, disappearanceTimeline.length)).join('\n')}',
    );
    expect(roomCleanEvents, 1);
    expect(completedEvents, 1);
    expect(verificationStartedAt, isNotNull);
    expect(completedAt, isNotNull);
    expect(
      completedAt!.difference(verificationStartedAt!),
      greaterThanOrEqualTo(const Duration(seconds: 2)),
      reason: 'completion requires a sustained second empty-room check',
    );
    expect(sessions.session?.status, CleanupStatus.completed);
    expect(sessions.session?.confirmedCollected, 1);
  });
}
