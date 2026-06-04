import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../business/review/candidate_review_controller.dart';

/// Compact summary chip surfaced on the live screen so the parent can see
/// the candidate-review breakdown at a glance:
///
///     Detected: 5 · Confirmed: 3 · Review: 2
///
/// Numbers come from the candidate-review state, not the legacy
/// ToyCountSummary — both coexist in Phase 4.2.
class CandidateReviewSummaryChip extends ConsumerWidget {
  const CandidateReviewSummaryChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(candidateReviewControllerProvider).summary;
    if (s.detected == 0) {
      return const SizedBox.shrink();
    }
    // Phase 5.0 simplified copy: 3 numbers, no per-category breakdown.
    final text = 'Detected ${s.detected} · '
        '${s.confirmed} toy · ${s.ignored} ignored';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
