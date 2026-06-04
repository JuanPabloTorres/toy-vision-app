import 'package:flutter/material.dart';

import '../../business/progress/achievement.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "Logros" card: a wrap of achievement badges. Unlocked badges are bright
/// and colorful; locked ones are dimmed with a small lock, so the child
/// sees both what they earned and what's next.
class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.unlocked).length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: AppColors.missionYellow,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('Logros', style: AppTypography.missionTitle),
              ),
              Text(
                '$unlocked / ${achievements.length}',
                style: AppTypography.parentValue.copyWith(
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final a in achievements) _Badge(achievement: a),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.missionYellow.withValues(alpha: 0.18)
                  : AppColors.textSecondary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: unlocked
                    ? AppColors.missionYellow
                    : AppColors.textSecondary.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: unlocked
                ? Text(
                    achievement.emoji,
                    style: const TextStyle(fontSize: 26),
                  )
                : const Icon(
                    Icons.lock_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.parentLabel.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  unlocked ? AppColors.textBlueDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
