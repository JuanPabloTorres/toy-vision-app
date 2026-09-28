import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:toyvision_realtime/application/cleanup/cleanup_session_service.dart';
import 'package:toyvision_realtime/application/cleanup/room_clean_verifier.dart';
import 'package:toyvision_realtime/domain/cleanup/cleanup_event.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/perception/perception_engine.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';
import 'package:toyvision_realtime/perception/room_discovery/room_discovery_session.dart';

void main() {
  test('J: multi-toy progress is monotonic and follows valid removals',
      () async {
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService(
      roomCleanVerifier: _replayRoomVerifier(),
    );
    final origin = DateTime.utc(2026);
    final specifications = <_SceneSpec>[
      for (var index = 0; index < 13; index++)
        const _SceneSpec(firstX: 0.15, secondX: 0.62),
      const _SceneSpec(firstX: 0.20, secondX: 0.62),
      const _SceneSpec(firstX: 0.26, secondX: 0.62),
      for (var index = 0; index < 12; index++) const _SceneSpec(secondX: 0.62),
      for (var index = 0; index < 3; index++) const _SceneSpec(secondX: 0.56),
      for (var index = 0; index < 3; index++) const _SceneSpec(secondX: 0.49),
      for (var index = 0; index < 17; index++) const _SceneSpec(),
    ];
    final progress = <int>[];
    final disappearanceTimeline = <String>[];
    var completed = 0;

    for (var index = 0; index < specifications.length; index++) {
      final frame = _render(
        specifications[index],
        frameId: index,
        timestamp: origin.add(Duration(milliseconds: index * 300)),
      );
      final perception = await engine.processFrame(
        frame,
        discoveryMode: cleanup.snapshot == null,
      );
      final outcome = cleanup.process(
        perception,
        allowCollection: cleanup.session != null,
      );
      for (final evidence in perception.disappearanceEvidence.values) {
        disappearanceTimeline.add(
          'frame $index track ${evidence.trackId}: '
          '${evidence.rejectionReasons.join(',')}',
        );
      }
      if (outcome.initialSnapshot != null && cleanup.session == null) {
        cleanup.startCleanup(frame.timestamp);
      }
      for (final event in outcome.events) {
        if (event is CleanupProgressChanged) progress.add(event.collected);
        if (event is CleanupCompleted) completed += 1;
      }
      for (final trackId in outcome.tracksToMarkCollected) {
        engine.markCollected(trackId, frame.timestamp);
      }
    }

    expect(cleanup.snapshot?.toys, hasLength(2));
    expect(
      progress,
      [1, 2],
      reason: disappearanceTimeline.takeLast(16).join('\n'),
    );
    expect(cleanup.session?.confirmedCollected, 2);
    expect(completed, 1);
  });

  test('a newly revealed toy waits for the final sweep', () async {
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
    var discovered = 0;

    for (var index = 0; index < 24; index++) {
      final secondVisible = index >= 13;
      final frame = _render(
        _SceneSpec(firstX: 0.15, secondX: secondVisible ? 0.62 : null),
        frameId: index,
        timestamp: origin.add(Duration(milliseconds: index * 300)),
      );
      final perception = await engine.processFrame(
        frame,
        discoveryMode: cleanup.snapshot == null,
      );
      final outcome = cleanup.process(
        perception,
        allowCollection: cleanup.session != null,
      );
      if (outcome.initialSnapshot != null && cleanup.session == null) {
        cleanup.startCleanup(frame.timestamp);
      }
      discovered += outcome.events.whereType<NewToyDiscovered>().length;
    }

    expect(discovered, 0);
    expect(cleanup.snapshot?.toys, hasLength(1));
    expect(cleanup.session?.remainingEstimate, 1);
    expect(cleanup.session?.confirmedCollected, 0);
  });

  test('core flow rebases the room anchor before the next physical pickup',
      () async {
    final engine = HybridToyPerceptionEngine();
    final cleanup = CleanupSessionService(
      roomCleanVerifier: _replayRoomVerifier(),
    );
    final origin = DateTime.utc(2026, 2);
    final specifications = <_SceneSpec>[
      for (var index = 0; index < 13; index++)
        const _SceneSpec(firstX: .15, secondX: .62),
      const _SceneSpec(firstX: .21, secondX: .62),
      const _SceneSpec(firstX: .27, secondX: .62),
      for (var index = 0; index < 14; index++) const _SceneSpec(secondX: .62),
      const _SceneSpec(secondX: .56, backgroundShift: 48),
      const _SceneSpec(secondX: .50, backgroundShift: 96),
      for (var index = 0; index < 5; index++)
        const _SceneSpec(secondX: .50, backgroundShift: 96),
      const _SceneSpec(secondX: .56, backgroundShift: 96),
      const _SceneSpec(secondX: .62, backgroundShift: 96),
      for (var index = 0; index < 18; index++)
        const _SceneSpec(backgroundShift: 96),
    ];
    final progress = <int>[];
    var collectedDuringPan = false;
    var completed = 0;
    final disappearanceTimeline = <String>[];

    for (var index = 0; index < specifications.length; index++) {
      final frame = _render(
        specifications[index],
        frameId: index,
        timestamp: origin.add(Duration(milliseconds: index * 300)),
      );
      final perception = await engine.processFrame(
        frame,
        discoveryMode: cleanup.snapshot == null,
      );
      final outcome = cleanup.process(
        perception,
        allowCollection: cleanup.session != null,
      );
      for (final evidence in perception.disappearanceEvidence.values) {
        disappearanceTimeline.add(
          'frame $index track ${evidence.trackId}: '
          '${evidence.rejectionReasons.join(',')}',
        );
      }
      if (outcome.initialSnapshot != null && cleanup.session == null) {
        cleanup.startCleanup(frame.timestamp);
      }
      for (final event in outcome.events) {
        if (event is CleanupProgressChanged) progress.add(event.collected);
        if (event is CleanupCompleted) completed += 1;
        if (index >= 29 && index <= 35 && event is ToyCollected) {
          collectedDuringPan = true;
        }
      }
      for (final trackId in outcome.tracksToMarkCollected) {
        engine.markCollected(trackId, frame.timestamp);
      }
    }

    expect(collectedDuringPan, isFalse);
    expect(
      progress,
      [1, 2],
      reason: disappearanceTimeline.takeLast(18).join('\n'),
    );
    expect(cleanup.session?.confirmedCollected, 2);
    expect(completed, 1);
  });
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) => skip((length - count).clamp(0, length));
}

CameraPerceptionFrame _render(
  _SceneSpec spec, {
  required int frameId,
  required DateTime timestamp,
}) {
  const width = 320;
  const height = 240;
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(145, 145, 145));
  final stripeOffset = spec.backgroundShift % 24;
  for (var x = -24 + stripeOffset; x < width; x += 24) {
    img.drawLine(
      image,
      x1: x,
      y1: 0,
      x2: x,
      y2: height - 1,
      color: img.ColorRgb8(160, 160, 160),
    );
  }
  if (spec.backgroundShift != 0) {
    final landmarkX = (36 + spec.backgroundShift).clamp(0, width - 62);
    img.fillRect(
      image,
      x1: landmarkX,
      y1: 32,
      x2: landmarkX + 62,
      y2: 92,
      color: img.ColorRgb8(105, 120, 128),
    );
  }
  final detections = <DetectorProposal>[];
  if (spec.firstX != null) {
    final box = NormalizedBox(
      x: spec.firstX!,
      y: 0.30,
      width: 0.18,
      height: 0.24,
    );
    _draw(image, box, img.ColorRgb8(220, 35, 45));
    detections.add(
      DetectorProposal(
        bounds: box,
        confidence: 0.92,
        knownClass: 'diagnostic-a',
      ),
    );
  }
  if (spec.secondX != null) {
    final box = NormalizedBox(
      x: spec.secondX!,
      y: 0.48,
      width: 0.16,
      height: 0.20,
    );
    _draw(image, box, img.ColorRgb8(35, 80, 220));
    detections.add(
      DetectorProposal(
        bounds: box,
        confidence: 0.92,
        knownClass: 'diagnostic-b',
      ),
    );
  }
  return CameraPerceptionFrame(
    frameId: frameId,
    timestamp: timestamp,
    encodedImage: img.encodeJpg(image, quality: 92),
    detectorProposals: detections,
    nativeInferenceMs: 30,
    nativeFps: 8,
  );
}

void _draw(img.Image image, NormalizedBox box, img.Color color) {
  img.fillRect(
    image,
    x1: (box.x * image.width).round(),
    y1: (box.y * image.height).round(),
    x2: (box.right * image.width).round(),
    y2: (box.bottom * image.height).round(),
    color: color,
  );
}

class _SceneSpec {
  const _SceneSpec({
    this.firstX,
    this.secondX,
    this.backgroundShift = 0,
  });

  final double? firstX;
  final double? secondX;
  final int backgroundShift;
}

RoomCleanVerifier _replayRoomVerifier() => EvidenceBasedRoomCleanVerifier(
      policy: const RoomCleanPolicy(
        minimumCleanDuration: Duration(seconds: 2),
        minimumCleanFrames: 3,
        minimumViewpoints: 1,
        minimumCameraMotion: 0,
      ),
    );
