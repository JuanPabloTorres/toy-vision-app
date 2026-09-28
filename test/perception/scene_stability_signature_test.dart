import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:toyvision_realtime/domain/scene/scene_descriptor.dart';
import 'package:toyvision_realtime/domain/scene/scene_state.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/domain/toy/toy_observation.dart';
import 'package:toyvision_realtime/domain/toy/toy_track.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';
import 'package:toyvision_realtime/perception/scene/scene_anchor_update_policy.dart';
import 'package:toyvision_realtime/perception/scene/scene_stability_service.dart';
import 'package:toyvision_realtime/perception/visual_frame_analyzer.dart';

void main() {
  test('spatial scene signature detects a camera pan and later recovers', () {
    const analyzer = VisualFrameAnalyzer();
    final stability = SceneStabilityService();
    final origin = DateTime.utc(2026);
    final first = analyzer.analyze(_frame(_room(shift: 0), origin));
    final shifted = analyzer.analyze(
      _frame(_room(shift: 64), origin.add(const Duration(milliseconds: 200))),
    );

    expect(stability.evaluate(first, origin).state, SceneState.unstable);
    final changed = stability.evaluate(
      shifted,
      origin.add(const Duration(milliseconds: 200)),
    );
    expect(changed.state, isNot(SceneState.stable));
    expect(changed.similarityToPrevious, lessThan(0.88));

    stability.evaluate(
      shifted,
      origin.add(const Duration(milliseconds: 400)),
    );
    final recovered = stability.evaluate(
      shifted,
      origin.add(const Duration(milliseconds: 600)),
    );
    expect(recovered.state, SceneState.stable);
  });

  test('stable anchor follows the next viewpoint between pickup episodes', () {
    const analyzer = VisualFrameAnalyzer();
    final stability = SceneStabilityService();
    final origin = DateTime.utc(2026);
    final first = analyzer.analyze(_frame(_room(shift: 0), origin));
    final second = analyzer.analyze(
      _frame(_room(shift: 64), origin.add(const Duration(seconds: 1))),
    );
    final third = analyzer.analyze(
      _frame(_room(shift: 128), origin.add(const Duration(seconds: 2))),
    );

    for (var index = 0; index < 3; index++) {
      stability.evaluate(
        first,
        origin.add(Duration(milliseconds: index * 200)),
      );
    }
    late SceneDescriptor rebased;
    for (var index = 0; index < 3; index++) {
      rebased = stability.evaluate(
        second,
        origin.add(Duration(milliseconds: 1000 + index * 200)),
        allowAnchorUpdate: true,
      );
    }
    expect(rebased.state, SceneState.stable);
    expect(rebased.similarityToStableAnchor, closeTo(1, 1e-9));

    late SceneDescriptor frozen;
    for (var index = 0; index < 3; index++) {
      frozen = stability.evaluate(
        third,
        origin.add(Duration(milliseconds: 2000 + index * 200)),
        allowAnchorUpdate: false,
      );
    }
    expect(frozen.state, SceneState.stable);
    expect(frozen.similarityToStableAnchor, lessThan(0.90));
  });

  test('anchor policy freezes only a causal pickup episode', () {
    const policy = SceneAnchorUpdatePolicy();
    final now = DateTime.utc(2026);
    final visible = _track(now, presence: TrackPresence.visible);
    final missingWithoutInteraction = _track(
      now,
      presence: TrackPresence.missingCandidate,
    );
    final physicalPickup = _track(
      now,
      presence: TrackPresence.missingCandidate,
      interactionEvidence: 0.4,
      lastInteractionAt: now,
    );

    expect(
      policy.canUpdate(discoveryMode: false, tracks: [visible]),
      isTrue,
    );
    expect(
      policy.canUpdate(
        discoveryMode: false,
        tracks: [missingWithoutInteraction],
      ),
      isTrue,
    );
    expect(
      policy.canUpdate(discoveryMode: false, tracks: [physicalPickup]),
      isFalse,
    );
    expect(
      policy.canUpdate(discoveryMode: true, tracks: [physicalPickup]),
      isTrue,
    );
  });
}

ToyTrack _track(
  DateTime at, {
  required TrackPresence presence,
  double interactionEvidence = 0,
  DateTime? lastInteractionAt,
}) =>
    ToyTrack(
      id: 1,
      lastBounds: const NormalizedBox(x: .2, y: .2, width: .2, height: .2),
      initialBounds: const NormalizedBox(x: .2, y: .2, width: .2, height: .2),
      visualEmbedding: const [1, 0],
      visibleFrames: 10,
      missingFrames: presence == TrackPresence.missingCandidate ? 3 : 0,
      confidence: .9,
      presence: presence,
      firstSeenAt: at.subtract(const Duration(seconds: 3)),
      lastSeenAt: at,
      updatedAt: at,
      source: ObservationSource.detector,
      confirmedToy: true,
      confirmedAt: at.subtract(const Duration(seconds: 3)),
      interactionEvidence: interactionEvidence,
      lastInteractionAt: lastInteractionAt,
      missingSince: presence == TrackPresence.missingCandidate ? at : null,
    );

CameraPerceptionFrame _frame(img.Image image, DateTime timestamp) =>
    CameraPerceptionFrame(
      frameId: timestamp.millisecondsSinceEpoch,
      timestamp: timestamp,
      encodedImage: img.encodeJpg(image, quality: 95),
      detectorProposals: const [],
      nativeInferenceMs: 0,
      nativeFps: 8,
    );

img.Image _room({required int shift}) {
  final image = img.Image(width: 320, height: 240);
  img.fill(image, color: img.ColorRgb8(130, 145, 150));
  img.fillRect(
    image,
    x1: (20 + shift) % 250,
    y1: 25,
    x2: (90 + shift) % 250 + 60,
    y2: 105,
    color: img.ColorRgb8(225, 45, 55),
  );
  img.fillRect(
    image,
    x1: (180 + shift) % 280,
    y1: 130,
    x2: ((180 + shift) % 280 + 70).clamp(0, 319),
    y2: 220,
    color: img.ColorRgb8(35, 80, 220),
  );
  return image;
}
