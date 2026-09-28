import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/settings/app_settings_controller.dart';
import '../../domain/toy/toy_track.dart';
import '../../ui/theme/app_colors.dart';
import 'camera_preview_geometry.dart';

/// Child-facing visual projection of the tracker state.
///
/// This layer deliberately exposes no detector labels, confidence values or
/// track IDs. It only translates already-established perception state into a
/// playful visual language; it cannot confirm or collect a toy.
class ToyHaloLayer extends ConsumerStatefulWidget {
  const ToyHaloLayer({
    super.key,
    required this.tracks,
    required this.sourceWidth,
    required this.sourceHeight,
    this.activeTrackId,
  });

  final Iterable<ToyTrack> tracks;
  final int sourceWidth;
  final int sourceHeight;
  final int? activeTrackId;

  @override
  ConsumerState<ToyHaloLayer> createState() => _ToyHaloLayerState();
}

class _ToyHaloLayerState extends ConsumerState<ToyHaloLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appAnimations = ref.watch(
      appSettingsProvider.select((settings) => settings.animationsEnabled),
    );
    final platformAnimations = !MediaQuery.disableAnimationsOf(context);
    final motionEnabled = appAnimations && platformAnimations;
    final visibleTracks = selectDistinctToyHalos(
      widget.tracks,
      activeTrackId: widget.activeTrackId,
    );

    return Semantics(
      container: true,
      label: visibleTracks.isEmpty
          ? 'Buscando cosas por recoger'
          : '${visibleTracks.length} ${visibleTracks.length == 1 ? 'objeto resaltado' : 'objetos resaltados'}',
      child: IgnorePointer(
        child: TickerMode(
          enabled: motionEnabled,
          child: CustomPaint(
            painter: _ToyHaloPainter(
              tracks: visibleTracks,
              sourceWidth: widget.sourceWidth,
              sourceHeight: widget.sourceHeight,
              activeTrackId: widget.activeTrackId,
              pulse: _pulse,
              motionEnabled: motionEnabled,
            ),
          ),
        ),
      ),
    );
  }
}

/// Defensive UI projection: even if an in-flight session predates perception
/// consolidation, one physical region receives one child-facing halo.
List<ToyTrack> selectDistinctToyHalos(
  Iterable<ToyTrack> tracks, {
  int? activeTrackId,
}) {
  final ranked =
      tracks.where((track) => track.isVisible && track.confirmedToy).toList()
        ..sort((left, right) {
          final leftPriority = (left.id == activeTrackId ? 10.0 : 0.0) +
              (left.isStable ? 2.0 : 0.0) +
              left.confidence;
          final rightPriority = (right.id == activeTrackId ? 10.0 : 0.0) +
              (right.isStable ? 2.0 : 0.0) +
              right.confidence;
          return rightPriority.compareTo(leftPriority);
        });
  final kept = <ToyTrack>[];
  for (final track in ranked) {
    final duplicate = kept.any((existing) {
      final iou = existing.lastBounds.intersectionOverUnion(track.lastBounds);
      final containment =
          existing.lastBounds.intersectionOverSmaller(track.lastBounds);
      final centroid = existing.lastBounds.centroidSimilarity(track.lastBounds);
      return centroid >= 0.94 && (iou >= 0.62 || containment >= 0.90);
    });
    if (!duplicate) kept.add(track);
  }
  return kept;
}

class _ToyHaloPainter extends CustomPainter {
  _ToyHaloPainter({
    required this.tracks,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.activeTrackId,
    required this.pulse,
    required this.motionEnabled,
  }) : super(repaint: motionEnabled ? pulse : null);

  final List<ToyTrack> tracks;
  final int sourceWidth;
  final int sourceHeight;
  final int? activeTrackId;
  final Animation<double> pulse;
  final bool motionEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (sourceWidth <= 0 || sourceHeight <= 0) return;
    final preview = CameraPreviewGeometry(
      viewport: size,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
    for (final track in tracks) {
      final mappedRect = preview.map(track.lastBounds);
      final active = track.id == activeTrackId;
      final confirmed = track.isStable;
      final pulseValue =
          motionEnabled ? Curves.easeInOut.transform(pulse.value) : 0.35;
      final rect = active ? mappedRect.inflate(2 + pulseValue) : mappedRect;
      final color = active
          ? AppColors.energyYellow
          : confirmed
              ? AppColors.energyGreen
              : AppColors.overlayCyan;

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: active ? 0.08 : 0.04);
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active
            ? 7 + (2 * pulseValue)
            : confirmed
                ? 5
                : 4
        ..color = color.withValues(
          alpha: active
              ? 0.28 + (0.10 * pulseValue)
              : confirmed
                  ? 0.20
                  : 0.12,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active
            ? 3.2
            : confirmed
                ? 2.6
                : 2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: confirmed || active ? 1 : 0.72);
      final rounded = RRect.fromRectAndRadius(
        rect,
        Radius.circular(
          math.min(16, math.min(rect.width, rect.height) * 0.18),
        ),
      );
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(
        rounded,
        glow,
      );
      _drawFriendlyCorners(canvas, rect, line, active ? 18 : 14);

      if (active) {
        _drawStarBadge(canvas, rect.topLeft, color);
      } else if (confirmed) {
        _drawCheckBadge(canvas, rect.topRight, color);
      }
    }
  }

  void _drawFriendlyCorners(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double cornerLength,
  ) {
    final radius = math.min(18.0, math.min(rect.width, rect.height) * 0.16);
    final safeCornerLength = math.min(
      cornerLength,
      math.max(2, math.min(rect.width, rect.height) * 0.22),
    );
    final path = Path()
      ..moveTo(rect.left, rect.top + radius + safeCornerLength)
      ..lineTo(rect.left, rect.top + radius)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + radius, rect.top)
      ..lineTo(rect.left + radius + safeCornerLength, rect.top)
      ..moveTo(rect.right - radius - safeCornerLength, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + radius)
      ..lineTo(rect.right, rect.top + radius + safeCornerLength)
      ..moveTo(rect.right, rect.bottom - radius - safeCornerLength)
      ..lineTo(rect.right, rect.bottom - radius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - radius,
        rect.bottom,
      )
      ..lineTo(rect.right - radius - safeCornerLength, rect.bottom)
      ..moveTo(rect.left + radius + safeCornerLength, rect.bottom)
      ..lineTo(rect.left + radius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - radius,
      )
      ..lineTo(rect.left, rect.bottom - radius - safeCornerLength);
    canvas.drawPath(path, paint);
  }

  void _drawCheckBadge(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8.5, Paint()..color = color);
    final check = Path()
      ..moveTo(center.dx - 4, center.dy)
      ..lineTo(center.dx - 1, center.dy + 3)
      ..lineTo(center.dx + 5, center.dy - 4);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawStarBadge(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 13, Paint()..color = Colors.white);
    final star = Path();
    for (var index = 0; index < 10; index++) {
      final radius = index.isEven ? 9.0 : 4.2;
      final angle = (-math.pi / 2) + (index * math.pi / 5);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (index == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ToyHaloPainter oldDelegate) =>
      oldDelegate.tracks != tracks ||
      oldDelegate.sourceWidth != sourceWidth ||
      oldDelegate.sourceHeight != sourceHeight ||
      oldDelegate.activeTrackId != activeTrackId ||
      oldDelegate.motionEnabled != motionEnabled;
}
