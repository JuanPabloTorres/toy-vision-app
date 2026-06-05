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
    final baseColor =
        isPrimary ? scheme.primary : scheme.surfaceContainerHighest;
    final topColor = _lighten(baseColor, 0.15);
    final bottomColor = _darken(baseColor, 0.12);

    final style = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(baseColor),
      foregroundColor: WidgetStatePropertyAll(
        isPrimary ? scheme.onPrimary : scheme.onSurface,
      ),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 2;
        return 7;
      }),
      shadowColor: const WidgetStatePropertyAll(Color(0x30000000)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
      side: WidgetStatePropertyAll(
        BorderSide(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.25),
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

    return FilledButton(
      onPressed: onPressed,
      style: style.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return bottomColor;
          return baseColor;
        }),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, baseColor, bottomColor],
            stops: const [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg - 2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: child,
        ),
      ),
    );
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}
