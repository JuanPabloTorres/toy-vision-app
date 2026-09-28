import 'package:flutter/material.dart';

import '../ui/theme/app_button_styles.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_radii.dart';
import '../ui/theme/app_typography.dart';

// Re-export every design token from a single entry point so existing code
// keeps importing `app_theme.dart` while the tokens live under
// `lib/ui/theme/`. New code should prefer importing the token files
// directly.
export '../ui/theme/app_colors.dart';
export '../ui/theme/app_spacing.dart';
export '../ui/theme/app_radii.dart';
export '../ui/theme/app_typography.dart';
export '../ui/theme/app_shadows.dart';
export '../ui/theme/app_button_styles.dart';

/// MaterialApp theme. Phase 6.4: **light** scheme to match the concept
/// art — light-blue scaffold, white cards, blue brand. The mission
/// (camera) screen still paints its own dark surfaces on top of the
/// preview.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.surface,
      primary: AppColors.primaryBlue,
      secondary: AppColors.missionYellow,
      tertiary: AppColors.gamePurple,
      error: AppColors.stopRed,
      onSurface: AppColors.textBlueDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      filledButtonTheme: FilledButtonThemeData(
        style: AppButtonStyles.filled(
          background: colorScheme.primary,
          foreground: colorScheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.outlined(color: colorScheme.primary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonStyles.text(color: AppColors.textBlueDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(
            color: AppColors.primaryBlue.withValues(alpha: 0.16),
            width: 2,
          ),
        ),
        titleTextStyle: AppTypography.cardTitle,
        contentTextStyle: AppTypography.body,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textBlueDark,
        contentTextStyle: AppTypography.bodyStrong.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.surfaceSoft,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          minimumSize: const Size(48, 48),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: AppTypography.celebrationHeadline,
        titleLarge: AppTypography.missionTitle,
        bodyMedium: TextStyle(color: AppColors.textBlueDark),
        labelLarge: AppTypography.buttonPrimary,
      ),
    );
  }

  /// Kept so any caller still asking for `dark()` compiles. Returns the
  /// light theme — the app is light-themed now.
  static ThemeData dark() => light();
}
