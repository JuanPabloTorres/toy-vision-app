import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../business/review/toy_candidate_status.dart';
import '../../tracking/tracked_toy.dart';
import '../theme/app_colors.dart';

/// Canonical colour for a candidate-review status. Kept here so the review
/// panel and any tap-routing share the same mapping.
Color colorForCandidateStatus(ToyCandidateStatus status) => switch (status) {
      ToyCandidateStatus.pending => AppColors.candidatePending,
      ToyCandidateStatus.confirmedToy => AppColors.candidateConfirmed,
      ToyCandidateStatus.notToy => AppColors.candidateNotToy,
      ToyCandidateStatus.unsure => AppColors.candidateUnsure,
      ToyCandidateStatus.ignoredAutomatic => AppColors.candidateIgnoredAuto,
    };

/// Kid-friendly detection overlay matching the concept art.
///
/// Draws **corner-bracket frames** (camera-focus style) instead of plain
/// rectangles:
/// - **Target** toy (`id == targetToyId`): thick yellow corners + a soft
///   highlight wash inside, and a light floating "Recoge este" marker above.
/// - **Secondary** toys: thin green corners, no label.
///
/// Boxes are in normalized `[0,1]` space (`TrackedToy.box`) and scaled to
/// the canvas, which fills the same rounded camera card as the YOLO
/// preview, so the brackets sit on top of each detected toy.
class DetectionOverlayPainter extends CustomPainter {
  DetectionOverlayPainter({
    required this.toys,
    required this.targetToyId,
  });

  final List<TrackedToy> toys;
  final int? targetToyId;

  /// Frames-missing over which a remembered (but currently unseen) frame
  /// fades from full brightness to [_minStaleOpacity]. At ~8 FPS this is
  /// roughly one second, matching the controller's target-lost grace window.
  static const double _staleFadeFrames = 8;

  /// A stale frame never disappears entirely: the mission invariant is that
  /// the highlight is always shown. It just dims to "last seen here, move the
  /// camera" instead of claiming the toy is right there.
  static const double _minStaleOpacity = 0.3;

  /// 1.0 while the detector still sees the toy this frame; fades toward
  /// [_minStaleOpacity] the longer it has been missing.
  double _opacityFor(TrackedToy toy) =>
      opacityForFramesMissing(toy.framesMissing);

  /// Maps a frame's "frames missing" to a draw opacity. Pure + exposed for
  /// testing: 0 missing → fully bright (the detector sees it now); fades
  /// linearly to [_minStaleOpacity] over [_staleFadeFrames] and never below,
  /// so a remembered target dims to "last seen here" but is always shown.
  @visibleForTesting
  static double opacityForFramesMissing(int framesMissing) {
    if (framesMissing <= 0) return 1;
    final t = (framesMissing / _staleFadeFrames).clamp(0.0, 1.0);
    return 1 - (1 - _minStaleOpacity) * t;
  }

  /// Throttle for the alignment diagnostic (static so it survives the
  /// per-build re-creation of the painter).
  static int _alignLogTick = 0;

  /// Logs how a normalized box maps onto the canvas, so misalignment
  /// ("box off the toy") can be diagnosed from logcat without guessing.
  /// `OverlayDX:` — canvas size/aspect, the normalized box, the rendered
  /// pixel box, and whether it lands inside the preview.
  void _maybeLogAlignment(Size size) {
    if (!kDebugMode || toys.isEmpty) return;
    if ((_alignLogTick++ % 30) != 0) return;
    final toy = toys.firstWhere(
      (t) => t.id == targetToyId,
      orElse: () => toys.first,
    );
    final raw = _rectFor(toy, size);
    final inside = raw.left >= -0.5 &&
        raw.top >= -0.5 &&
        raw.right <= size.width + 0.5 &&
        raw.bottom <= size.height + 0.5;
    final fitted = _safeRectFor(toy, size);
    String f(double v) => v.toStringAsFixed(2);
    String r(Rect? b) => b == null
        ? 'null'
        : '(${b.left.toStringAsFixed(0)},${b.top.toStringAsFixed(0)},'
            '${b.width.toStringAsFixed(0)},${b.height.toStringAsFixed(0)})';
    debugPrint('OverlayDX: widgetSize=${size.width.toStringAsFixed(0)}x'
        '${size.height.toStringAsFixed(0)} '
        'canvasAR=${f(size.width / size.height)} '
        'normBox=(${f(toy.box.x)},${f(toy.box.y)},'
        '${f(toy.box.width)},${f(toy.box.height)}) '
        'renderedBox=${r(raw)} drawnBox=${r(fitted)} '
        'isInsidePreview=$inside');
  }

  @override
  void paint(Canvas canvas, Size size) {
    _maybeLogAlignment(size);
    // Secondary first so the target frame + label sit on top.
    for (final toy in toys) {
      if (toy.id == targetToyId) continue;
      final rect = _safeRectFor(toy, size);
      if (rect == null) continue;
      _drawCornerFrame(
        canvas,
        rect,
        color: AppColors.boxSecondary,
        strokeWidth: 4,
        opacity: _opacityFor(toy),
      );
    }
    for (final toy in toys) {
      if (toy.id != targetToyId) continue;
      final rect = _safeRectFor(toy, size);
      if (rect == null) continue;
      final opacity = _opacityFor(toy);
      // Soft highlight wash inside the chosen toy so it clearly reads as
      // "this one" — the reference the child should pick up — instead of
      // looking like just another framed toy.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()
          ..color = AppColors.boxTarget.withValues(alpha: 0.14 * opacity),
      );
      _drawCornerFrame(
        canvas,
        rect,
        color: AppColors.boxTarget,
        strokeWidth: 6,
        opacity: opacity,
      );
      _drawTargetLabel(canvas, rect, size, opacity: opacity);
    }
  }

  /// Box rect clamped to the preview. Returns null when the box has no
  /// meaningful overlap with the visible preview (so we never draw a frame
  /// floating outside the camera area — a coordinate-mapping safety net).
  Rect? _safeRectFor(TrackedToy toy, Size size) {
    final raw = _rectFor(toy, size);
    // Mandatory clamp before drawing. A box that fits but spills over an edge
    // is SHIFTED inward (keeps full size, so a near-edge toy still gets a full
    // bracket). A box larger than the preview is clamped by intersection.
    final Rect fitted;
    if (raw.width >= size.width || raw.height >= size.height) {
      fitted = raw.intersect(Offset.zero & size);
    } else {
      final left = raw.left.clamp(0.0, size.width - raw.width);
      final top = raw.top.clamp(0.0, size.height - raw.height);
      fitted = Rect.fromLTWH(left, top, raw.width, raw.height);
    }
    if (fitted.width < 4 || fitted.height < 4) return null;
    return fitted;
  }

  /// L-shaped brackets at each corner of [rect].
  void _drawCornerFrame(
    Canvas canvas,
    Rect rect, {
    required Color color,
    required double strokeWidth,
    double opacity = 1,
  }) {
    // Bracket arm length: a quarter of the shorter side, clamped so it
    // never looks like a full box on small detections.
    final arm = (math.min(rect.width, rect.height) * 0.28).clamp(12.0, 44.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity);

    // Soft glow behind the brackets for the "highlighted toy" look.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.25 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final p in [glow, paint]) {
      // Top-left
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.top + arm)
          ..lineTo(rect.left, rect.top)
          ..lineTo(rect.left + arm, rect.top),
        p,
      );
      // Top-right
      canvas.drawPath(
        Path()
          ..moveTo(rect.right - arm, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + arm),
        p,
      );
      // Bottom-left
      canvas.drawPath(
        Path()
          ..moveTo(rect.left, rect.bottom - arm)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.left + arm, rect.bottom),
        p,
      );
      // Bottom-right
      canvas.drawPath(
        Path()
          ..moveTo(rect.right - arm, rect.bottom)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.right, rect.bottom - arm),
        p,
      );
    }
  }

  /// "Recoge este" floating marker centered above the target frame: a small
  /// hand chip plus the words, kept light (no boxed pill) so it reads as
  /// guidance floating over the camera rather than a button. Fades with the
  /// frame so a stale (currently unseen) target dims to "last seen here".
  void _drawTargetLabel(
    Canvas canvas,
    Rect rect,
    Size size, {
    double opacity = 1,
  }) {
    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'Recoge este',
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.55 * opacity),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.35 * opacity),
              blurRadius: 9,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // A hand reaching to pick up — reads as the "recoge" (pick this up)
    // action far more directly than a generic toy pictogram.
    const pickupIcon = Icons.back_hand_rounded;
    final pickupIconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(pickupIcon.codePoint),
        style: TextStyle(
          fontFamily: pickupIcon.fontFamily,
          package: pickupIcon.fontPackage,
          color: Colors.white.withValues(alpha: opacity),
          fontSize: 17,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const iconD = 26.0;
    const gap = 7.0;
    final rowW = iconD + gap + labelPainter.width;

    var left = rect.left + rect.width / 2 - rowW / 2;
    left = left.clamp(4.0, math.max(4.0, size.width - rowW - 4));
    var top = rect.top - iconD - 8;
    if (top < 4) top = 4;

    // Round hand chip — the only solid shape, kept small and circular so the
    // marker never reads as a boxed-in container. A soft shadow lets it float.
    final iconCenter = Offset(left + iconD / 2, top + iconD / 2);
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: iconCenter, radius: iconD / 2)),
      Colors.black.withValues(alpha: 0.4 * opacity),
      3,
      true,
    );
    canvas.drawCircle(
      iconCenter,
      iconD / 2,
      Paint()..color = AppColors.missionYellow.withValues(alpha: opacity),
    );
    canvas.drawCircle(
      iconCenter,
      iconD / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.85 * opacity),
    );
    pickupIconPainter.paint(
      canvas,
      Offset(
        iconCenter.dx - pickupIconPainter.width / 2,
        iconCenter.dy - pickupIconPainter.height / 2,
      ),
    );

    // Words floating beside the chip — shadowed for legibility over the
    // camera, with no surrounding box.
    labelPainter.paint(
      canvas,
      Offset(
        left + iconD + gap,
        iconCenter.dy - labelPainter.height / 2,
      ),
    );
  }

  Rect _rectFor(TrackedToy toy, Size size) => Rect.fromLTWH(
        toy.box.x * size.width,
        toy.box.y * size.height,
        toy.box.width * size.width,
        toy.box.height * size.height,
      );

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter old) =>
      old.toys != toys || old.targetToyId != targetToyId;
}
