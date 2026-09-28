import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';

import '../support/camera_replay.dart';

void main() {
  test('unknown persistent object stays unconfirmed without semantic evidence',
      () async {
    final replay = CameraReplay.load(
      'test/fixtures/replays/cleanup_adverse.json',
    );
    final engine = HybridToyPerceptionEngine();
    final origin = DateTime.utc(2026);
    var sawOpenSetProposal = false;
    var sawConfirmedTrack = false;
    var sawUnconfirmedCandidate = false;

    for (var index = 0; index < 10; index++) {
      final source = replay.frames[index];
      final frame = ReplayFrame(
        milliseconds: source.milliseconds,
        background: source.background,
        toy: true,
        detect: false,
      );
      final result = await engine.processFrame(
        replay.render(frame, frameId: index, origin: origin),
        discoveryMode: true,
      );
      sawOpenSetProposal |= result.metrics.openSetProposalCount > 0;
      sawConfirmedTrack |= result.worldModel.activeTracks.values.any(
        (track) => track.isStable,
      );
      sawUnconfirmedCandidate |= result.uncertainObservations.isNotEmpty;
    }

    expect(sawOpenSetProposal, isTrue);
    expect(sawUnconfirmedCandidate, isTrue);
    expect(sawConfirmedTrack, isFalse);
  });
}
