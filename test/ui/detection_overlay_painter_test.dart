import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/ui/overlays/detection_overlay_painter.dart';

/// Regression guard for the opacity helper only. The mission controller now
/// owns target visibility: a lost target is removed from the overlay instead
/// of being painted from a stale remembered box.
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

    test('keeps stale helper opacity bounded for non-target remembered boxes',
        () {
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
