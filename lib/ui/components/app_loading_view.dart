import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'lottie_status_view.dart';

/// Friendly full-area loading state. Shows a Lottie animation when the
/// asset is present, otherwise an animated Material icon, plus a short
/// message. Reused by splash, model loading, and the scanning phase.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    required this.message,
    this.subMessage,
    this.lottieAsset = 'assets/lottie/mission_loading.json',
    this.fallbackIcon = Icons.smart_toy_rounded,
    this.background,
  });

  final String message;
  final String? subMessage;
  final String lottieAsset;
  final IconData fallbackIcon;
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
          LottieStatusView(
            assetPath: lottieAsset,
            fallbackIcon: fallbackIcon,
            size: 120,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.missionTitle,
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.parentLabel,
            ),
          ],
        ],
      ),
    );
  }
}
