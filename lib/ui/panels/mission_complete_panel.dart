import 'package:flutter/material.dart';

import '../components/lottie_status_view.dart';
import '../components/primary_action_button.dart';
import '../components/secondary_action_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Full-screen celebration that takes over the camera when Mateo finishes
/// the mission. Big, friendly, one CTA.
class MissionCompletePanel extends StatelessWidget {
  const MissionCompletePanel({
    super.key,
    required this.collectedToyCount,
    required this.onNewMission,
    this.onSeeStars,
  });

  final int collectedToyCount;
  final VoidCallback onNewMission;

  /// Optional "Ver mis estrellas" action. When null (e.g. in isolated widget
  /// tests) only the primary "Nueva misión" CTA is shown.
  final VoidCallback? onSeeStars;

  /// Friendly summary line, with correct Spanish singular/plural for the
  /// toy count ("1 juguete" vs "N juguetes").
  String get _summary {
    if (collectedToyCount <= 0) return '¡La zona quedó limpia!';
    final noun = collectedToyCount == 1 ? 'juguete' : 'juguetes';
    return 'Recogiste $collectedToyCount $noun. ¡Bien hecho!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.80),
      // Center the card when it fits, but SCROLL instead of overflowing when
      // vertical space is tight (short screens / landscape). Fixes the
      // "BOTTOM OVERFLOWED" celebration-panel bug seen in landscape.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - AppSpacing.xl * 2)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: AppColors.panelInkDark.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.5,
            ),
            boxShadow: AppShadows.celebrationGlow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.celebrationGlow,
                ),
                child: LottieStatusView(
                  assetPath: 'assets/lottie/mission_complete.json',
                  fallbackIcon: Icons.emoji_events_rounded,
                  size: 150,
                  fallbackColor: AppColors.gameYellow,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _RewardStars(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '¡Terminaste!',
                textAlign: TextAlign.center,
                style: AppTypography.celebrationHeadline.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _summary,
                textAlign: TextAlign.center,
                style: AppTypography.coachMessage.copyWith(
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (onSeeStars != null) ...[
                SecondaryActionButton(
                  label: 'Ver mis estrellas',
                  expand: false,
                  fill: AppColors.gameYellow,
                  labelColor: AppColors.textBlueDark,
                  leading: SecondaryActionButton.circledIcon(
                    Icons.star_rounded,
                    color: AppColors.gamePurple,
                  ),
                  onPressed: onSeeStars!,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              PrimaryActionButton(
                label: 'Nueva misión',
                color: AppColors.gameGreen,
                fontSize: 18,
                expand: false,
                borderRadius: AppRadii.xl,
                leading: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: onNewMission,
              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three celebratory stars, the middle one bigger — a lightweight "reward
/// badge" that reads as a prize without needing a confetti asset.
class _RewardStars extends StatelessWidget {
  const _RewardStars();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_rounded, color: AppColors.missionYellow, size: 34),
        SizedBox(width: AppSpacing.sm),
        Icon(Icons.star_rounded, color: AppColors.missionYellow, size: 52),
        SizedBox(width: AppSpacing.sm),
        Icon(Icons.star_rounded, color: AppColors.missionYellow, size: 34),
      ],
    );
  }
}
