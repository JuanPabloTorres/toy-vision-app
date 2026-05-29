import 'dart:typed_data';

import 'package:camera/camera.dart' show ImageFormatGroup;
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/image_format_converter.dart';
import 'package:toyvision_realtime/detection/detectors/tflite/tflite_runtime_exception.dart';

void main() {
  const converter = ImageFormatConverter();

  // 2x2 YUV420 frame: Y stride 2; chroma is 1x1 (one shared U/V sample).
  RawCameraFrame yuv({required int yFill, required int u, required int v}) {
    return RawCameraFrame(
      format: ImageFormatGroup.yuv420,
      width: 2,
      height: 2,
      planes: [
        RawImagePlane(
          bytes: Uint8List(4)..fillRange(0, 4, yFill),
          bytesPerRow: 2,
        ),
        RawImagePlane(
          bytes: Uint8List.fromList([u]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
        RawImagePlane(
          bytes: Uint8List.fromList([v]),
          bytesPerRow: 1,
          bytesPerPixel: 1,
        ),
      ],
    );
  }

  test('YUV420 black frame -> RGB all zeros', () {
    final rgb = converter.convert(yuv(yFill: 0, u: 128, v: 128));
    expect(rgb.bytes.length, 2 * 2 * 3);
    expect(rgb.bytes.every((b) => b == 0), isTrue);
  });

  test('YUV420 white frame -> RGB all 255', () {
    final rgb = converter.convert(yuv(yFill: 255, u: 128, v: 128));
    expect(rgb.bytes.every((b) => b == 255), isTrue);
  });

  test('YUV420 red-ish frame -> high R, low G/B', () {
    final rgb = converter.convert(yuv(yFill: 76, u: 84, v: 255));
    expect(rgb.bytes[0], greaterThanOrEqualTo(250)); // R
    expect(rgb.bytes[1], lessThanOrEqualTo(5)); // G
    expect(rgb.bytes[2], lessThanOrEqualTo(5)); // B
  });

  test('BGRA8888 -> RGB channel reorder', () {
    final frame = RawCameraFrame(
      format: ImageFormatGroup.bgra8888,
      width: 1,
      height: 1,
      planes: [
        RawImagePlane(
          bytes: Uint8List.fromList([10, 20, 30, 255]), // B,G,R,A
          bytesPerRow: 4,
          bytesPerPixel: 4,
        ),
      ],
    );
    final rgb = converter.convert(frame);
    expect(rgb.bytes, [30, 20, 10]); // R,G,B
  });

  test('unsupported format fails safely', () {
    const frame = RawCameraFrame(
      format: ImageFormatGroup.jpeg,
      width: 2,
      height: 2,
      planes: [],
    );
    expect(
      () => converter.convert(frame),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('YUV420 with too few planes fails safely', () {
    final frame = RawCameraFrame(
      format: ImageFormatGroup.yuv420,
      width: 2,
      height: 2,
      planes: [
        RawImagePlane(bytes: Uint8List(4), bytesPerRow: 2),
      ],
    );
    expect(
      () => converter.convert(frame),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('YUV420 with short Y plane fails safely', () {
    final frame = RawCameraFrame(
      format: ImageFormatGroup.yuv420,
      width: 2,
      height: 2,
      planes: [
        RawImagePlane(bytes: Uint8List(1), bytesPerRow: 2), // too short
        RawImagePlane(bytes: Uint8List(1), bytesPerRow: 1, bytesPerPixel: 1),
        RawImagePlane(bytes: Uint8List(1), bytesPerRow: 1, bytesPerPixel: 1),
      ],
    );
    expect(
      () => converter.convert(frame),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });

  test('BGRA8888 with short plane fails safely', () {
    final frame = RawCameraFrame(
      format: ImageFormatGroup.bgra8888,
      width: 2,
      height: 2,
      planes: [
        RawImagePlane(bytes: Uint8List(4), bytesPerRow: 8), // too short for 2x2
      ],
    );
    expect(
      () => converter.convert(frame),
      throwsA(isA<TfliteRuntimeException>()),
    );
  });
}
