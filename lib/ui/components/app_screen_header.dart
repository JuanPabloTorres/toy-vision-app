import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_back_button.dart';

/// The one header used across screens, so every title looks the same size,
/// weight and color, sits at the same height, and pairs with the same back
/// control.
///
/// Two shapes, one widget:
/// * **Primary tab** (Home, Mis estrellas, Para padres) — no back button, a
///   big friendly title and an optional one-line subtitle. Pass [trailing]
///   for a corner control (sound toggle, avatar).
/// * **Secondary screen** (mission intro, a history day) — set [showBack] so
///   the canonical [AppBackButton] appears on the left; the title still uses
///   the same style, so navigating never changes how a header feels.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.titleStyle,
  });

  final String title;

  /// Optional one-line supporting copy under the title.
  final String? subtitle;

  /// When true, renders the canonical [AppBackButton] on the left.
  final bool showBack;

  /// Tap handler for the back button (e.g. to play a sound first). When null
  /// the back button just pops the route.
  final VoidCallback? onBack;

  /// Optional corner control aligned to the title row's right edge.
  final Widget? trailing;

  /// Overrides the title style. Defaults to [AppTypography.heading].
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: titleStyle ?? AppTypography.heading),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTypography.body.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack) ...[
          AppBackButton(onPressed: onBack),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(child: titleColumn),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
