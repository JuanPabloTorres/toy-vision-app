import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';

/// Shared button tokens to keep visual behavior uniform across all screens.
class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle filled({
    Color background = AppColors.primaryBlue,
    Color foreground = Colors.white,
    double radius = AppRadii.xl,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.md,
    ),
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return background.withValues(alpha: 0.45);
        }
        return background;
      }),
      foregroundColor: WidgetStatePropertyAll(foreground),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 2;
        return 7;
      }),
      shadowColor: const WidgetStatePropertyAll(Color(0x30000000)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Color(0x14FFFFFF)),
      padding: WidgetStatePropertyAll(padding),
      side: WidgetStatePropertyAll(
        BorderSide(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.25),
      ),
    );
  }

  static ButtonStyle outlined({
    Color color = AppColors.primaryBlue,
    double radius = AppRadii.lg,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(vertical: AppSpacing.md),
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return color.withValues(alpha: 0.4);
        }
        return color;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: color.withValues(alpha: 0.3), width: 1.5);
        }
        return BorderSide(color: color, width: 1.8);
      }),
      backgroundColor: const WidgetStatePropertyAll(Color(0x0DFFFFFF)),
      overlayColor: WidgetStatePropertyAll(color.withValues(alpha: 0.10)),
      padding: WidgetStatePropertyAll(padding),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }

  static ButtonStyle text({
    Color color = AppColors.textBlueDark,
    double radius = AppRadii.md,
  }) {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return color.withValues(alpha: 0.4);
        }
        return color;
      }),
      overlayColor: WidgetStatePropertyAll(color.withValues(alpha: 0.10)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.15),
      ),
    );
  }
}
