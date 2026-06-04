import 'package:flutter/material.dart';

import '../components/app_glass_panel.dart';
import '../components/tobi_mascot.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Floating bubble that shows Tobi's coach message — the one instruction
/// Mateo should follow right now.
///
/// Renders prepared text only; never derives game state.
class CleanupCoachBubble extends StatelessWidget {
  const CleanupCoachBubble({
    super.key,
    required this.message,
    this.mascotName = 'Tobi',
  });

  final String message;
  final String mascotName;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: AppGlassPanel(
        key: ValueKey(message),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const TobiMascot(size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$mascotName dice',
                      style: AppTypography.coachName,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AppTypography.coachMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft bubble used inline (e.g. in the parent-controls sheet) when the
/// glass background would clash with the surrounding surface. Same copy,
/// flat surface.
class CleanupCoachInlineLine extends StatelessWidget {
  const CleanupCoachInlineLine({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.gameBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(message, style: AppTypography.coachMessage),
    );
  }
}
