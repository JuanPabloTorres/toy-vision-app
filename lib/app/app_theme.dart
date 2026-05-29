import 'package:flutter/material.dart';

/// Centralized design tokens and theme for ToyVision.
///
/// Per the reusable-components and ui-ux governance, all colors, spacing,
/// radii, shadows, durations, and overlay opacity live here. Widgets and
/// components must read these tokens, never hardcode visual values.

class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF4F6BED);
  static const Color surface = Color(0xFF101218);
  static const Color onSurface = Color(0xFFF2F4F8);
  static const Color onSurfaceMuted = Color(0xFFAAB2C5);

  static const Color boxToy = Color(0xFF5BE3A6);
  static const Color boxCounted = Color(0xFF4F6BED);
  static const Color badgeBg = Color(0x33FFFFFF);

  static const Color statusReady = Color(0xFF5BE3A6);
  static const Color statusBusy = Color(0xFFF2C14E);
  static const Color statusError = Color(0xFFEF6F6C);

  static const Color glassFill = Color(0x33121620);
  static const Color glassBorder = Color(0x33FFFFFF);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
}

class AppOpacity {
  AppOpacity._();

  /// Opacity of translucent panels rendered over the camera preview.
  static const double glassPanel = 0.6;

  /// Fill opacity used inside detection bounding boxes.
  static const double boxFill = 0.18;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.surface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: AppColors.onSurface),
        labelLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
