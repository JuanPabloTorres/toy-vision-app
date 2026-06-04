import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../business/review/candidate_object.dart';
import '../../business/review/candidate_review_controller.dart';
import '../../business/review/candidate_review_summary.dart';
import '../../business/review/toy_candidate_status.dart';
import '../../ui/overlays/detection_overlay_painter.dart';

/// Phase 5.0 review panel — deliberately simple.
///
/// Single scrollable list of every detected object. Each row shows the
/// detector's confidence and a status dot, with one or two action buttons
/// depending on the row's current state:
///
///   - pending  → `Count as toy` + `Ignore`
///   - confirmed → `Undo`
///   - ignored / not toy → `Undo`
///
/// There are no tabs, no product categories, and no per-category counters.
/// The product goal at this phase is just "did the user say this counts as a
/// toy or not". Anything more granular waits until the simple flow is proven
/// useful on real devices.
class ReviewPanel extends ConsumerWidget {
  const ReviewPanel({super.key});

  /// Open the review panel as a modal bottom sheet on top of the live screen.
  static Future<void> show(BuildContext context) {
    if (kDebugMode) debugPrint('CandidateDX: reviewPanel.show');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => const ReviewPanel(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(candidateReviewControllerProvider);
    final controller = ref.read(candidateReviewControllerProvider.notifier);

    // Sort: pending first (newest at top), then confirmed, then ignored.
    int statusOrder(CandidateObject c) => switch (c.status) {
          ToyCandidateStatus.pending || ToyCandidateStatus.unsure => 0,
          ToyCandidateStatus.confirmedToy => 1,
          ToyCandidateStatus.notToy || ToyCandidateStatus.ignoredAutomatic => 2,
        };
    final candidates = [...state.all]..sort((a, b) {
        final o = statusOrder(a).compareTo(statusOrder(b));
        if (o != 0) return o;
        return b.lastSeenFrameIndex.compareTo(a.lastSeenFrameIndex);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const _GrabHandle(),
            _Header(summary: state.summary),
            const Divider(height: 1, color: AppColors.glassBorder),
            Expanded(
              child: candidates.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _CandidateRow(
                        candidate: candidates[i],
                        onCount: () => controller.markToy(candidates[i].id),
                        onIgnore: () => controller.markNotToy(candidates[i].id),
                        onUndo: () => controller.markUnsure(candidates[i].id),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary});
  final CandidateReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Text(
            'Review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _SummaryChip(label: 'Detected', value: summary.detected),
          const SizedBox(width: AppSpacing.xs),
          _SummaryChip(label: 'Confirmed', value: summary.confirmed),
          const SizedBox(width: AppSpacing.xs),
          _SummaryChip(label: 'Ignored', value: summary.ignored),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No detections yet. Point the camera at toys.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.onCount,
    required this.onIgnore,
    required this.onUndo,
  });

  final CandidateObject candidate;
  final VoidCallback onCount;
  final VoidCallback onIgnore;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final color = colorForCandidateStatus(candidate.status);
    final confidence = (candidate.detectorConfidence * 100).round();
    final statusLabel = switch (candidate.status) {
      ToyCandidateStatus.pending => 'Detected',
      ToyCandidateStatus.confirmedToy => 'Counted as toy',
      ToyCandidateStatus.notToy => 'Ignored',
      ToyCandidateStatus.unsure => 'Unsure',
      ToyCandidateStatus.ignoredAutomatic => 'Auto-ignored',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Object #${candidate.id}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$statusLabel · detector $confidence%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _RowActions(
            status: candidate.status,
            onCount: onCount,
            onIgnore: onIgnore,
            onUndo: onUndo,
          ),
        ],
      ),
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.status,
    required this.onCount,
    required this.onIgnore,
    required this.onUndo,
  });

  final ToyCandidateStatus status;
  final VoidCallback onCount;
  final VoidCallback onIgnore;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ToyCandidateStatus.confirmedToy:
      case ToyCandidateStatus.notToy:
      case ToyCandidateStatus.ignoredAutomatic:
        return Row(
          children: [
            _ActionButton(
              label: 'Undo',
              color: AppColors.candidateUnsure,
              onTap: onUndo,
            ),
          ],
        );
      case ToyCandidateStatus.pending:
      case ToyCandidateStatus.unsure:
        return Row(
          children: [
            _ActionButton(
              label: 'Count as toy',
              color: AppColors.candidateConfirmed,
              onTap: onCount,
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(
              label: 'Ignore',
              color: AppColors.candidateNotToy,
              onTap: onIgnore,
            ),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
