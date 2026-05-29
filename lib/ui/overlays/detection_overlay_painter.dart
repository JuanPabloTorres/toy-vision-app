import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../tracking/tracked_toy.dart';

/// Draws bounding boxes for tracked toys over the camera preview.
///
/// Painter pattern: it receives prepared state (tracked toys in normalized
/// coordinates) and only renders. It computes no counts, IoU, or validity.
class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter({required this.toys});

  final List<TrackedToy> toys;

  @override
  void paint(Canvas canvas, Size size) {
    for (final toy in toys) {
      final rect = Rect.fromLTWH(
        toy.box.x * size.width,
        toy.box.y * size.height,
        toy.box.width * size.width,
        toy.box.height * size.height,
      );

      final color = toy.hasBeenCounted ? AppColors.boxCounted : AppColors.boxToy;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: AppOpacity.boxFill);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;

      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(AppRadii.sm),
      );
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);

      _paintLabel(canvas, rect, toy.displayName, color);
    }
  }

  void _paintLabel(Canvas canvas, Rect rect, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect = Rect.fromLTWH(
      rect.left,
      (rect.top - tp.height - 6).clamp(0, double.infinity),
      tp.width + 12,
      tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(labelRect.left + 6, labelRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter old) =>
      old.toys != toys;
}
