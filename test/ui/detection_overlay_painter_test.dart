import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/ui/overlays/detection_overlay_painter.dart';

/// Regression guard for the "static box pointing at nothing" bug: once the
/// mission locks a target, its highlight is a remembered box. While the
/// detector still sees the toy it is drawn bright; the longer it has been
/// missing the more it fades — but it never disappears (mission invariant:
/// the highlight is always shown).
void main() {
  group('DetectionOverlayPainter.opacityForFramesMissing', () {
    test('fully bright while the detector sees the toy this frame', () {
      expect(DetectionOverlayPainter.opacityForFramesMissing(0), 1.0);
    });

    test('a freshly-lost toy starts dimming immediately', () {
      final o = DetectionOverlayPainter.opacityForFramesMissing(1);
      expect(o, lessThan(1.0));
      expect(o, greaterThan(0.3));
    });

    test('fade is monotonic as the toy stays missing', () {
      final a = DetectionOverlayPainter.opacityForFramesMissing(2);
      final b = DetectionOverlayPainter.opacityForFramesMissing(5);
      expect(b, lessThan(a));
    });

    test('never fades below the floor, so the highlight is always shown', () {
      expect(
        DetectionOverlayPainter.opacityForFramesMissing(8),
        closeTo(0.3, 1e-9),
      );
      expect(
        DetectionOverlayPainter.opacityForFramesMissing(999),
        closeTo(0.3, 1e-9),
      );
    });
  });
}
