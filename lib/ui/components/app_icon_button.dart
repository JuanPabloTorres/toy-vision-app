import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Reusable circular icon control (pause, reset, save). Presentation only.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? scheme.primary : AppColors.badgeBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Icon(
              icon,
              color: emphasized ? scheme.onPrimary : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
