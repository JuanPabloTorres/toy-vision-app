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
    required this.collected,
    required this.remainingEstimate,
    this.activeToyId,
    this.completionEvidence,
  });

  final PerceptionResult result;
  final CleanupPhase phase;
  final int collected;
  final int remainingEstimate;
  final int? activeToyId;
  final CompletionEvidence? completionEvidence;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _DeveloperVisionPainter(
            result,
            phase,
            collected,
            remainingEstimate,
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
    this.collected,
    this.remainingEstimate,
    this.activeToyId,
    this.completionEvidence,
  );

  final PerceptionResult result;
  final CleanupPhase phase;
  final int collected;
  final int remainingEstimate;
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
        'direct:${evidence.directPickupEvidence ? 'Y' : 'N'} '
        'camLoss:${track.lostDuringCameraMotion ? 'Y' : 'N'} '
        'depth:${evidence.depthChangeScore?.toStringAsFixed(2) ?? '-'} '
        '${evidence.rejectionReasons.join('|')}',
      );
    }

    final summary = buildDeveloperVisionSummary(
      result: result,
      phase: phase,
      collected: collected,
      remainingEstimate: remainingEstimate,
      activeToyId: activeToyId,
      completionEvidence: completionEvidence,
    );
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
      maxLines: 8,
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
      oldDelegate.collected != collected ||
      oldDelegate.remainingEstimate != remainingEstimate ||
      oldDelegate.activeToyId != activeToyId ||
      oldDelegate.completionEvidence?.cleanDecision !=
          completionEvidence?.cleanDecision ||
      oldDelegate.completionEvidence?.noToyDuration !=
          completionEvidence?.noToyDuration ||
      oldDelegate.completionEvidence?.sceneCoverage !=
          completionEvidence?.sceneCoverage;
}

String buildDeveloperVisionSummary({
  required PerceptionResult result,
  required CleanupPhase phase,
  required int collected,
  required int remainingEstimate,
  int? activeToyId,
  CompletionEvidence? completionEvidence,
}) {
  final scene = result.worldModel.scene;
  final completion = completionEvidence;
  final reappeared = result.transitions
      .where((transition) => transition.type == TrackTransitionType.reappeared)
      .map((transition) => transition.trackId)
      .join(',');
  final transition = result.transitions.isEmpty
      ? '-'
      : result.transitions
          .map((item) => '${item.type.name}#${item.trackId}')
          .join(',');
  final targetRemoval =
      activeToyId == null ? null : result.disappearanceEvidence[activeToyId];
  final blockers = completion?.blockingReasons.isEmpty ?? true
      ? '-'
      : completion!.blockingReasons.join('|');

  return 'DEV frame:${result.metrics.frameId} PHASE:${phase.name} '
      'ACTIVE:${activeToyId ?? '-'}\n'
      'YOLO:${result.metrics.detectorProposalCount} '
      'OPEN:${result.metrics.openSetProposalCount} '
      'CONF:${result.acceptedObservations.length} '
      'CAND:${result.uncertainObservations.length}\n'
      'TRACK active:${result.worldModel.activeTracks.length} '
      'missing:${result.worldModel.missingTracks.length} '
      'collected:$collected remaining:$remainingEstimate\n'
      'SCENE:${scene.state.name} verify:${scene.canVerifyDisappearance} '
      'motion:${scene.spatial.normalizedMotion.toStringAsFixed(2)} '
      'anchor:${scene.similarityToStableAnchor.toStringAsFixed(2)}\n'
      'REMOVE:${targetRemoval?.confirmed == true ? 'CONFIRMED' : 'WAIT'} '
      'missingMs:${targetRemoval?.missingDuration.inMilliseconds ?? '-'} '
      'reacquired:${reappeared.isEmpty ? 'NO' : reappeared} '
      'transition:$transition\n'
      'ROOM coverage:${completion?.sceneCoverage.toStringAsFixed(2) ?? '-'} '
      'stable:${completion?.sceneStable ?? '-'} '
      'tracking:${completion?.cameraTrackingGood ?? '-'} '
      'emptyMs:${completion?.noToyDuration.inMilliseconds ?? '-'}\n'
      'DECISION:${completion?.cleanDecision.name ?? '-'} BLOCK:$blockers';
}
