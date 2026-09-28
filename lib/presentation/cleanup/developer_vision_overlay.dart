import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/toy/toy_observation.dart';
import '../../perception/perception_models.dart';
import '../../application/cleanup/cleanup_state.dart';
import '../../application/cleanup/room_clean_verifier.dart';
import 'camera_preview_geometry.dart';

class DeveloperVisionOverlay extends StatelessWidget {
  const DeveloperVisionOverlay({
    super.key,
    required this.result,
    required this.phase,
    this.activeToyId,
    this.completionEvidence,
  });

  final PerceptionResult result;
  final CleanupPhase phase;
  final int? activeToyId;
  final CompletionEvidence? completionEvidence;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _DeveloperVisionPainter(
            result,
            phase,
            activeToyId,
            completionEvidence,
          ),
        ),
      );
}

class _DeveloperVisionPainter extends CustomPainter {
  const _DeveloperVisionPainter(
    this.result,
    this.phase,
    this.activeToyId,
    this.completionEvidence,
  );

  final PerceptionResult result;
  final CleanupPhase phase;
  final int? activeToyId;
  final CompletionEvidence? completionEvidence;

  @override
  void paint(Canvas canvas, Size size) {
    final analysis = result.trace.analysis;
    if (analysis.sourceWidth <= 0 || analysis.sourceHeight <= 0) return;
    final transform = CameraPreviewGeometry(
      viewport: size,
      sourceWidth: analysis.sourceWidth,
      sourceHeight: analysis.sourceHeight,
    );

    for (final candidate in analysis.candidates.take(24)) {
      final detector = candidate.source == ObservationSource.detector;
      _box(
        canvas,
        transform.map(candidate.bounds),
        detector ? const Color(0xFFFF5252) : const Color(0xFFFFA726),
        detector
            ? 'YOLO ${candidate.detectorConfidence.toStringAsFixed(2)}'
            : 'OPEN ${candidate.proposalConfidence.toStringAsFixed(2)}',
      );
    }
    for (final candidate in result.uncertainObservations.take(16)) {
      _box(
        canvas,
        transform.map(candidate.bounds),
        const Color(0xFFFFEB3B),
        'CAND ${candidate.toyProbability.toStringAsFixed(2)} '
        '${candidate.confirmationBlockers.join('|')}',
      );
    }
    for (final track in result.worldModel.activeTracks.values) {
      _box(
        canvas,
        transform.map(track.lastBounds),
        const Color(0xFF00E676),
        'TOY #${track.id} ${track.confidence.toStringAsFixed(2)} '
        'i:${track.interactionEvidence.toStringAsFixed(2)}',
        width: 4,
      );
    }
    for (final evidence in result.disappearanceEvidence.values) {
      final track = result.worldModel.missingTracks[evidence.trackId];
      if (track == null) continue;
      _box(
        canvas,
        transform.map(track.lastBounds),
        const Color(0xFF7C4DFF),
        'MISS #${track.id} ${evidence.missingDuration.inMilliseconds}ms '
        'gyro:${evidence.deviceMotion.toStringAsFixed(2)} '
        'bg:${evidence.backgroundRevealScore.toStringAsFixed(2)} '
        'depth:${evidence.depthChangeScore?.toStringAsFixed(2) ?? '-'} '
        '${evidence.rejectionReasons.join('|')}',
      );
    }

    final scene = result.worldModel.scene;
    final completion = completionEvidence;
    final summary = 'DEV  frame ${result.metrics.frameId} '
        'phase:${phase.name} activeToy:${activeToyId ?? '-'}\n'
        'scene:${scene.state.name} '
        'prev:${scene.similarityToPrevious.toStringAsFixed(2)} '
        'anchor:${scene.similarityToStableAnchor.toStringAsFixed(2)} '
        'stable:${scene.stableFrameCount}  '
        'YOLO:${result.metrics.detectorProposalCount} '
        'OPEN:${result.metrics.openSetProposalCount} '
        'TOY:${result.acceptedObservations.length} '
        'gyroMotion:${scene.spatial.normalizedMotion.toStringAsFixed(2)}\n'
        'roomCoverage:${completion?.sceneCoverage.toStringAsFixed(2) ?? '-'} '
        'confirmedToys:${completion?.confirmedToyCount ?? '-'} '
        'cleanDecision:${completion?.cleanDecision.name ?? '-'}';
    final text = TextPainter(
      text: TextSpan(
        text: summary,
        style: const TextStyle(
          color: Colors.white,
          backgroundColor: Color(0xCC000000),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 5,
    )..layout(maxWidth: size.width - 16);
    text.paint(canvas, const Offset(8, 116));
  }

  void _box(
    Canvas canvas,
    Rect rect,
    Color color,
    String label, {
    double width = 2,
  }) {
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black,
          backgroundColor: color.withValues(alpha: 0.88),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(70, rect.width));
    text.paint(canvas, Offset(rect.left, math.max(0, rect.top - text.height)));
  }

  @override
  bool shouldRepaint(_DeveloperVisionPainter oldDelegate) =>
      oldDelegate.result.metrics.frameId != result.metrics.frameId ||
      oldDelegate.phase != phase ||
      oldDelegate.activeToyId != activeToyId ||
      oldDelegate.completionEvidence?.cleanDecision !=
          completionEvidence?.cleanDecision;
}
