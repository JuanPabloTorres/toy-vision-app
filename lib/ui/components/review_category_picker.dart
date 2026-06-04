import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../business/review/toy_review_category.dart';

/// Compact category picker. Shows the current category (or "Choose category")
/// and a downward chevron; tapping opens a popup with every
/// [ToyReviewCategory].
///
/// Pure presentation — the caller wires [onSelected] to a controller method
/// such as `CandidateReviewController.categorize(id, category)`.
class ReviewCategoryPicker extends StatelessWidget {
  const ReviewCategoryPicker({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final ToyReviewCategory? current;
  final ValueChanged<ToyReviewCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = current?.displayName ?? 'Choose category';
    return PopupMenuButton<ToyReviewCategory>(
      tooltip: 'Pick category',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final cat in ToyReviewCategory.values)
          PopupMenuItem(value: cat, child: Text(cat.displayName)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.badgeBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
