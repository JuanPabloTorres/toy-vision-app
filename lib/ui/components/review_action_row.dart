import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../business/review/toy_candidate_status.dart';

/// Three side-by-side buttons — Toy / Not Toy / Unsure — for one candidate
/// row in the review panel. The current [status] is highlighted; tapping a
/// non-current option fires [onChange] with the new status.
class ReviewActionRow extends StatelessWidget {
  const ReviewActionRow({
    super.key,
    required this.status,
    required this.onChange,
  });

  final ToyCandidateStatus status;
  final ValueChanged<ToyCandidateStatus> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: 'Toy',
          selected: status == ToyCandidateStatus.confirmedToy,
          color: AppColors.candidateConfirmed,
          onTap: () => onChange(ToyCandidateStatus.confirmedToy),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ActionButton(
          label: 'Not toy',
          selected: status == ToyCandidateStatus.notToy,
          color: AppColors.candidateNotToy,
          onTap: () => onChange(ToyCandidateStatus.notToy),
        ),
        const SizedBox(width: AppSpacing.xs),
        _ActionButton(
          label: 'Unsure',
          selected: status == ToyCandidateStatus.unsure,
          color: AppColors.candidateUnsure,
          onTap: () => onChange(ToyCandidateStatus.unsure),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : color.withValues(alpha: 0.15);
    final fg = selected ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
