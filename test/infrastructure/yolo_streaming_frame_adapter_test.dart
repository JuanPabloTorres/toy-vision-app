import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/infrastructure/camera/yolo_streaming_frame_adapter.dart';

void main() {
  const adapter = YoloStreamingFrameAdapter();

  test('keeps every valid native object proposal regardless of label', () {
    final frame = adapter.adapt({
      'frameNumber': 17,
      'originalImage': Uint8List.fromList([1, 2, 3]),
      'processingTimeMs': 31.5,
      'fps': 9.2,
      'detections': [
        {
          'className': 'toilet',
          'confidence': 0.74,
          'normalizedBox': {
            'left': 0.1,
            'top': 0.2,
            'right': 0.4,
            'bottom': 0.6,
          },
        },
      ],
    });

    expect(frame.frameId, 17);
    expect(frame.detectorProposals, hasLength(1));
    expect(frame.detectorProposals.single.knownClass, 'toilet');
    expect(frame.detectorProposals.single.bounds.width, closeTo(0.3, 1e-9));
    expect(frame.detectorCoordinatesAreUpright, isTrue);
  });

  test('rejects payloads that cannot support real visual reasoning', () {
    expect(
      () => adapter.adapt({'detections': const []}),
      throwsA(isA<CameraFrameAdapterException>()),
    );
  });
}
