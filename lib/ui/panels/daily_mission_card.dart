import 'package:flutter/material.dart';

import '../components/app_playful_icon.dart';
import '../components/app_progress_bar.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "Misión del día" card on Home: a toy-basket illustration, the goal
/// text, and a progress bar (collected / goal).
class DailyMissionCard extends StatelessWidget {
  const DailyMissionCard({
    super.key,
    required this.collectedToday,
    required this.goal,
    this.rewardLabel = 'Estrella de limpieza',
  });

  final int collectedToday;
  final int goal;

  /// The visual prize the child earns by finishing the day's goal. Shown as a
  /// small badge so the mission feels rewarding, not like a chore.
  final String rewardLabel;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (collectedToday / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cream, // warm cream like the mockup
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
            ),
            child: const AppPlayfulIcon(
              symbol: AppPlayfulIconSymbol.dailyMission,
              size: 38,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Misión del día',
                        style: AppTypography.missionTitle,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.star_rounded,
                      color: AppColors.missionYellow,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Recoge $goal juguetes hoy',
                  style: AppTypography.parentLabel.copyWith(fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppProgressBar(
                        value: progress,
                        activeColor: AppColors.progressGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$collectedToday/$goal',
                      style: AppTypography.coachName.copyWith(
                        color: AppColors.progressGreen,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _RewardBadge(label: rewardLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Recompensa: …" chip — a soft yellow pill with a star, so the day's prize
/// reads as a treat the child is working toward.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.missionYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.gameOrange,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'Recompensa: $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.coachName.copyWith(
                color: AppColors.textBlueDark,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
