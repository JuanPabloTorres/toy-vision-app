import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/camera/services/frame_processing_service.dart';
import 'package:toyvision_realtime/core/config/realtime_detection_config.dart';
import 'package:toyvision_realtime/detection/detectors/mock_toy_detector.dart';
import 'package:toyvision_realtime/detection/detectors/toy_detector.dart';
import 'package:toyvision_realtime/detection/models/detection_frame.dart';
import 'package:toyvision_realtime/detection/models/raw_detection.dart';

/// Detector whose `detect` blocks until [release] is called — used to hold the
/// service in its busy state for the skip-if-busy test.
class BlockingDetector implements ToyDetector {
  final Completer<void> _gate = Completer<void>();
  int detectCalls = 0;

  void release() => _gate.complete();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<RawDetection>> detect(DetectionFrame frame) async {
    detectCalls++;
    await _gate.future;
    return const [];
  }

  @override
  void dispose() {}
}

void main() {
  // 8 fps -> 125 ms throttle interval.
  const config = RealtimeDetectionConfig(targetInferenceFps: 8);

  test('throttles frames arriving faster than the target interval', () async {
    var now = 0;
    final svc = FrameProcessingService(
      detector: MockToyDetector(),
      config: config,
      clock: () => now,
    );

    expect(await svc.process(null), isNotNull); // t=0 accepted
    now = 50;
    expect(await svc.process(null), isNull); // 50 < 125 -> throttled
    now = 130;
    expect(await svc.process(null), isNotNull); // >= 125 -> accepted
  });

  test('skips frames while inference is already running', () async {
    final blocking = BlockingDetector();
    var now = 0;
    final svc = FrameProcessingService(
      detector: blocking,
      config: config,
      clock: () => now,
    );

    final first = svc.process(null); // starts, becomes busy (awaits gate)
    await Future<void>.delayed(Duration.zero);
    expect(svc.isBusy, isTrue);

    now = 1000; // past throttle so only the busy guard can drop this one
    expect(await svc.process(null), isNull); // skipped: busy

    blocking.release();
    await first;
    expect(blocking.detectCalls, 1); // the skipped frame never reached detect
  });

  test('advances the accepted-frame index passed to the detector', () async {
    var now = 0;
    final svc = FrameProcessingService(
      detector: MockToyDetector(),
      config: config,
      clock: () => now,
    );

    await svc.process(null);
    now = 200;
    await svc.process(null);
    expect(svc.acceptedFrames, 2);
  });

  test('reset clears throttle and frame-index state', () async {
    const now = 0;
    final svc = FrameProcessingService(
      detector: MockToyDetector(),
      config: config,
      clock: () => now,
    );
    await svc.process(null);
    svc.reset();
    expect(svc.acceptedFrames, 0);
    expect(svc.isBusy, isFalse);
    // After reset the next frame is accepted immediately even at the same time.
    expect(await svc.process(null), isNotNull);
  });
}
