import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_image.dart';

class ToyBackground extends StatelessWidget {
  const ToyBackground({
    super.key,
    required this.child,
    this.asset = AppAssets.missionBackground,
    this.overlay = const Color(0x99F5FBFF),
    this.safeArea = true,
  });

  final Widget child;
  final String asset;
  final Color overlay;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        ColoredBox(color: overlay),
        child,
      ],
    );
    return safeArea ? SafeArea(child: content) : content;
  }
}

class ToyWordmark extends StatelessWidget {
  const ToyWordmark({super.key, this.fontSize = 34, this.centered = true});

  final double fontSize;
  final bool centered;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Tobi Ordena',
        header: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: centered ? Alignment.center : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              AppImage(
                assetPath: AppAssets.cameraIcon,
                fallbackIcon: Icons.center_focus_strong_rounded,
                fallbackColor: AppColors.primaryBlue,
                size: fontSize * 1.28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tobi',
                      style: TextStyle(color: AppColors.primaryBlue),
                    ),
                    TextSpan(
                      text: ' Ordena',
                      style: TextStyle(color: AppColors.celebrationOrange),
                    ),
                  ],
                ),
                style: AppTypography.wordmark.copyWith(
                  fontSize: fontSize,
                  shadows: const [
                    Shadow(color: Color(0x24000000), offset: Offset(0, 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class ToyCard extends StatelessWidget {
  const ToyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = Colors.white,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.card,
        ),
        child: Material(
          color: color,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            side: BorderSide(
              color: borderColor ?? Colors.white.withValues(alpha: 0.85),
              width: 2,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

class ToySpeechBubble extends StatelessWidget {
  const ToySpeechBubble({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ToyCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        borderColor: AppColors.overlayCyan,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.coachMessage,
        ),
      );
}

/// Shared introduction used at the top of kid and adult-facing pages.
///
/// The caller supplies the mascot so this presentation primitive stays
/// independent from the concrete 2D/3D Tobi implementation.
class ToyPageHero extends StatelessWidget {
  const ToyPageHero({
    super.key,
    required this.mascot,
    required this.message,
  });

  final Widget mascot;
  final String message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 340;
          if (compact) {
            return Column(
              children: [
                SizedBox(width: 104, height: 104, child: mascot),
                const SizedBox(height: AppSpacing.sm),
                ToySpeechBubble(message: message),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 108, height: 118, child: mascot),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: ToySpeechBubble(message: message)),
            ],
          );
        },
      );
}

/// A single visual grammar for informational and navigable list cards.
class ToyFeatureCard extends StatelessWidget {
  const ToyFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.assetPath,
    this.onTap,
    this.accent = AppColors.primaryBlue,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? assetPath;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: ToyCard(
          padding: EdgeInsets.zero,
          borderColor: accent.withValues(alpha: 0.24),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: assetPath == null
                        ? Icon(icon, color: accent, size: 30)
                        : AppImage(
                            assetPath: assetPath!,
                            fallbackIcon: icon,
                            fallbackColor: accent,
                            size: 42,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.cardTitle),
                        const SizedBox(height: AppSpacing.xs),
                        Text(body, style: AppTypography.body),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.chevron_right_rounded, color: accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

/// Consistent empty, loading and error surface with an optional action.
class ToyStateCard extends StatelessWidget {
  const ToyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.assetPath,
    this.action,
    this.accent = AppColors.primaryBlue,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? assetPath;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) => Center(
        child: ToyCard(
          borderColor: accent.withValues(alpha: 0.28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (assetPath == null)
                Icon(icon, color: accent, size: 68)
              else
                AppImage(
                  assetPath: assetPath!,
                  fallbackIcon: icon,
                  fallbackColor: accent,
                  size: 82,
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      );
}

class ToyIconAction extends StatelessWidget {
  const ToyIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primaryBlue,
    this.assetPath,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final String? assetPath;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: color.withValues(alpha: 0.30)),
                    boxShadow: AppShadows.card,
                  ),
                  child: assetPath == null
                      ? Icon(icon, color: color, size: 28)
                      : AppImage(
                          assetPath: assetPath!,
                          fallbackIcon: icon,
                          fallbackColor: color,
                          size: 42,
                        ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: AppTypography.caption),
              ],
            ),
          ),
        ),
      );
}

class ToyScreenHeader extends StatelessWidget {
  const ToyScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (onBack != null)
            IconButton.filledTonal(
              key: const Key('screen-back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          if (onBack != null) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTypography.heading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}
