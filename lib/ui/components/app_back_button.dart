import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The single "go back" control for every secondary screen.
///
/// Before this existed each screen hand-rolled its own round back button
/// (`_RoundButton` in the mission intro, the Material `AppBar` auto-back on
/// the history screens, …) — three different colors, sizes and positions for
/// the same action. This is the one canonical back control: a soft white
/// circle with the brand-blue arrow, a 48×48 tap target (comfortable for a
/// small child or an adult thumb), and a built-in ripple for touch feedback.
///
/// By default it pops the current route; pass [onPressed] when the screen
/// needs to do something first (e.g. play the tap sound) before popping.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back_rounded,
    this.semanticLabel = 'Volver',
  });

  /// Called on tap. When null, falls back to `Navigator.maybePop`.
  final VoidCallback? onPressed;

  /// The glyph shown. Defaults to a rounded back arrow; pass
  /// `Icons.close_rounded` for dismiss-style screens.
  final IconData icon;

  /// Accessibility label read by screen readers.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceCard,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: AppColors.shadowMedium,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          customBorder: const CircleBorder(),
          // md padding + 24px glyph = a 48×48 tap target.
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Icon(icon, color: AppColors.primaryDark, size: 24),
          ),
        ),
      ),
    );
  }
}
