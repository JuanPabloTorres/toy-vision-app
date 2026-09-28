import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/presentation/cleanup/camera_preview_geometry.dart';

void main() {
  test('rotates landscape sensor boxes onto a portrait camera preview', () {
    final geometry = CameraPreviewGeometry(
      viewport: const Size(360, 780),
      sourceWidth: 192,
      sourceHeight: 144,
    );

    final rect = geometry.map(
      const NormalizedBox(x: 0.4, y: 0.2, width: 0.1, height: 0.2),
    );

    expect(geometry.rotatesClockwise, isTrue);
    expect(rect.left, closeTo(238.5, 0.001));
    expect(rect.top, closeTo(312, 0.001));
    expect(rect.width, closeTo(117, 0.001));
    expect(rect.height, closeTo(78, 0.001));
  });

  test('keeps same-orientation preview coordinates unchanged', () {
    final geometry = CameraPreviewGeometry(
      viewport: const Size(640, 480),
      sourceWidth: 192,
      sourceHeight: 144,
    );

    final rect = geometry.map(
      const NormalizedBox(x: 0.2, y: 0.2, width: 0.1, height: 0.2),
    );

    expect(geometry.rotatesClockwise, isFalse);
    expect(rect.left, closeTo(128, 0.001));
    expect(rect.top, closeTo(96, 0.001));
    expect(rect.width, closeTo(64, 0.001));
    expect(rect.height, closeTo(96, 0.001));
  });

  test('does not rotate an already-upright YOLO box a second time', () {
    final geometry = CameraPreviewGeometry(
      viewport: const Size(360, 780),
      sourceWidth: 480,
      sourceHeight: 640,
    );

    final rect = geometry.map(
      const NormalizedBox(x: 0.6, y: 0.2, width: 0.2, height: 0.3),
    );

    expect(geometry.rotatesClockwise, isFalse);
    expect(rect.left, closeTo(238.5, 0.001));
    expect(rect.top, closeTo(156, 0.001));
    expect(rect.width, closeTo(117, 0.001));
    expect(rect.height, closeTo(234, 0.001));
  });
}
