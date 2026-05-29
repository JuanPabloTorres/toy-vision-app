import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

enum AppButtonVariant { primary, secondary }

/// Reusable button. All button styling in the app flows through this widget so
/// styles are never duplicated. It holds no business logic.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = variant == AppButtonVariant.primary;

    final style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(
        isPrimary ? scheme.primary : scheme.surfaceContainerHighest,
      ),
      foregroundColor: WidgetStatePropertyAll(
        isPrimary ? scheme.onPrimary : scheme.onSurface,
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
    );

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(label),
            ],
          );

    return FilledButton(onPressed: onPressed, style: style, child: child);
  }
}
