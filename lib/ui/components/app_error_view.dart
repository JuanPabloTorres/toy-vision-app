import 'package:flutter/material.dart';

import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Friendly full-area error state with a single retry action. Used when
/// YOLO fails to load — no fake detections, just a clear, kid-safe
/// message and a big "try again" button.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel = 'Reintentar',
    this.onAction,
    this.background,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background ?? AppColors.bgLight,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.stopRed.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              boxShadow: AppShadows.floatingBubble,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.stopRed,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.missionTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.parentLabel,
          ),
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
              style: AppButtonStyles.filled(
                background: AppColors.primaryBlue,
                radius: AppRadii.xl,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
