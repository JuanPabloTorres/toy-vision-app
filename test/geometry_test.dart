import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/geometry/bounding_box_mapper.dart';
import 'package:toyvision_realtime/detection/geometry/frame_orientation.dart';
import 'package:toyvision_realtime/detection/geometry/preview_coordinate_mapper.dart';
import 'package:toyvision_realtime/detection/geometry/rotation_transform.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';

void _expectBox(BoundingBox a, BoundingBox b) {
  expect(a.x, closeTo(b.x, 1e-9));
  expect(a.y, closeTo(b.y, 1e-9));
  expect(a.width, closeTo(b.width, 1e-9));
  expect(a.height, closeTo(b.height, 1e-9));
}

void main() {
  group('FrameOrientation', () {
    test('default is no rotation', () {
      expect(FrameOrientation.none.quarterTurns, 0);
    });

    test('back camera subtracts device rotation', () {
      const o = FrameOrientation(
        sensorOrientationDegrees: 90,
        deviceOrientationDegrees: 0,
      );
      expect(o.quarterTurns, 1);
    });

    test('back camera with matching device rotation needs no turn', () {
      const o = FrameOrientation(
        sensorOrientationDegrees: 90,
        deviceOrientationDegrees: 90,
      );
      expect(o.quarterTurns, 0);
    });

    test('front camera adds device rotation (mirrored)', () {
      const o = FrameOrientation(
        sensorOrientationDegrees: 270,
        deviceOrientationDegrees: 0,
        isFrontCamera: true,
      );
      expect(o.quarterTurns, 3);
    });
  });

  group('RotationTransform.rotateNormalized', () {
    const box = BoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);

    test('0 turns is identity', () {
      _expectBox(RotationTransform.rotateNormalized(box, 0), box);
    });

    test('90 degrees clockwise', () {
      _expectBox(
        RotationTransform.rotateNormalized(box, 1),
        const BoundingBox(x: 0.4, y: 0.1, width: 0.4, height: 0.3),
      );
    });

    test('180 degrees', () {
      _expectBox(
        RotationTransform.rotateNormalized(box, 2),
        const BoundingBox(x: 0.6, y: 0.4, width: 0.3, height: 0.4),
      );
    });

    test('270 degrees clockwise', () {
      _expectBox(
        RotationTransform.rotateNormalized(box, 3),
        const BoundingBox(x: 0.2, y: 0.6, width: 0.4, height: 0.3),
      );
    });

    test('two 90-degree turns equal one 180-degree turn', () {
      final twice = RotationTransform.rotateNormalized(
        RotationTransform.rotateNormalized(box, 1),
        1,
      );
      _expectBox(twice, RotationTransform.rotateNormalized(box, 2));
    });

    test('rotated boxes stay within the unit square', () {
      for (var q = 0; q < 4; q++) {
        final r = RotationTransform.rotateNormalized(box, q);
        expect(r.x, inInclusiveRange(0.0, 1.0));
        expect(r.y, inInclusiveRange(0.0, 1.0));
        expect(r.right, lessThanOrEqualTo(1.0 + 1e-9));
        expect(r.bottom, lessThanOrEqualTo(1.0 + 1e-9));
      }
    });

    test('clampNormalized pulls an out-of-range box back into [0,1]', () {
      const bad = BoundingBox(x: -0.1, y: 0.5, width: 2.0, height: 2.0);
      final c = RotationTransform.clampNormalized(bad);
      expect(c.x, 0.0);
      expect(c.right, lessThanOrEqualTo(1.0 + 1e-9));
      expect(c.bottom, lessThanOrEqualTo(1.0 + 1e-9));
    });
  });

  group('BoundingBoxMapper', () {
    test('normalized to pixel', () {
      const box = BoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);
      final px = BoundingBoxMapper.normalizedToPixel(box, 100, 200);
      expect(px.left, closeTo(10, 1e-9));
      expect(px.top, closeTo(40, 1e-9));
      expect(px.width, closeTo(30, 1e-9));
      expect(px.height, closeTo(80, 1e-9));
    });

    test('pixel to normalized is the inverse', () {
      const px = PixelBox(left: 10, top: 40, width: 30, height: 80);
      final box = BoundingBoxMapper.pixelToNormalized(px, 100, 200);
      _expectBox(
        box,
        const BoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
      );
    });

    test('invalid dimensions fail safely', () {
      const box = BoundingBox(x: 0, y: 0, width: 1, height: 1);
      expect(
        () => BoundingBoxMapper.normalizedToPixel(box, 0, 200),
        throwsArgumentError,
      );
    });
  });

  group('PreviewCoordinateMapper (BoxFit.cover)', () {
    test('cover scale takes the larger axis ratio', () {
      // 100x100 image into a 200x400 viewport -> scale 4 (height-bound).
      expect(
        PreviewCoordinateMapper.coverScale(100, 100, 200, 400),
        closeTo(4.0, 1e-9),
      );
    });

    test('cover offset crops the wider axis (negative dx)', () {
      final off = PreviewCoordinateMapper.coverOffset(100, 100, 200, 400);
      expect(off.dx, closeTo((200 - 400) / 2, 1e-9)); // -100
      expect(off.dy, closeTo(0, 1e-9));
    });

    test('maps a normalized box into preview pixels with crop offset', () {
      const box = BoundingBox(x: 0.0, y: 0.0, width: 1.0, height: 1.0);
      final px = PreviewCoordinateMapper.mapNormalizedBoxToPreview(
        box,
        imageWidth: 100,
        imageHeight: 100,
        previewWidth: 200,
        previewHeight: 400,
      );
      expect(px.left, closeTo(-100, 1e-9));
      expect(px.top, closeTo(0, 1e-9));
      expect(px.width, closeTo(400, 1e-9));
      expect(px.height, closeTo(400, 1e-9));
    });

    test('invalid dimensions fail safely', () {
      const box = BoundingBox(x: 0, y: 0, width: 1, height: 1);
      expect(
        () => PreviewCoordinateMapper.mapNormalizedBoxToPreview(
          box,
          imageWidth: 100,
          imageHeight: 100,
          previewWidth: 0,
          previewHeight: 400,
        ),
        throwsArgumentError,
      );
    });
  });
}
