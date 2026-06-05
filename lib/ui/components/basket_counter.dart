import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_playful_icon.dart';

/// "🧺 N / meta" — the challenge score shown during an active mission.
///
/// Extracted from the camera screen's private `_ScorePanel` (and replacing the
/// unused `LiveCounterPanel`) so the basket/score is one reusable widget. It
/// shows progress toward the GOAL (a challenge target, never "toys left in the
/// room"), the personal record to beat, and celebrates reaching the goal or
/// setting a new record. In free (record) mode there is no "/ meta" — every
/// pickup is a record attempt.
class BasketCounter extends StatelessWidget {
  const BasketCounter({
    super.key,
    required this.collected,
    required this.goal,
    required this.personalBest,
    required this.hasReachedGoal,
    required this.isNewRecord,
  });

  final int collected;
  final int? goal;
  final int personalBest;
  final bool hasReachedGoal;
  final bool isNewRecord;

  @override
  Widget build(BuildContext context) {
    final reached = hasReachedGoal || isNewRecord;
    final basketLabel = goal == null ? '$collected' : '$collected / $goal';
    final subLabel = isNewRecord
        ? '¡Nuevo récord!'
        : (personalBest > 0 ? 'Récord: $personalBest' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: reached
                ? AppColors.childFriendlyHighlight
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPlayfulIcon(
                symbol: AppPlayfulIconSymbol.toyBasket,
                size: 22,
                color: reached ? Colors.white : AppColors.primaryBlue,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                basketLabel,
                style: AppTypography.missionTitle.copyWith(
                  fontSize: 18,
                  color: reached ? Colors.white : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subLabel,
            style: AppTypography.missionTitle.copyWith(
              fontSize: 11,
              color: isNewRecord
                  ? AppColors.childFriendlyHighlight
                  : Colors.white,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
