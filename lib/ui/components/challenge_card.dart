import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A selectable challenge card for the mission-intro picker: a round goal
/// badge, the challenge title and a kid-facing one-liner, with a clear
/// selected/unselected state.
///
/// Extracted from the private `_ChallengeCard` so the "pick your reto" card
/// is a single reusable, token-driven widget instead of inline screen code.
/// It takes plain values (not a business model) so it stays a pure
/// presentation component.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;

  /// Short badge text — the target count, or "∞" for a free-play challenge.
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSelected = selected ? Colors.white : AppColors.primaryDark;
    return Material(
      color: selected ? AppColors.childFriendlyHighlight : AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      elevation: selected ? 4 : 1,
      shadowColor: AppColors.shadowSoft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      selected ? Colors.white : AppColors.childFriendlyHighlight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge,
                  style: AppTypography.missionTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: selected
                        ? AppColors.childFriendlyHighlight
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.missionTitle.copyWith(
                        color: onSelected,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: AppTypography.body.copyWith(color: onSelected),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
