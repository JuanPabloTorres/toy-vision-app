import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A small section header: optional leading icon chip, a title, and an
/// optional trailing action ("Ver más"). Used on Home above the daily
/// mission and calendar cards.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primaryBlue;
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(title, style: AppTypography.missionTitle),
        ),
        if (trailingLabel != null)
          TextButton(
            onPressed: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: AppTypography.coachName.copyWith(fontSize: 14),
            ),
          ),
      ],
    );
  }
}
