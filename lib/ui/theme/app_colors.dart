import 'package:flutter/material.dart';

/// Single source of truth for every color in Toy Vision.
///
/// Phase 6.4: the palette switched from the old dark camera theme to the
/// **light, playful** scheme shown in the concept art — light-blue
/// backgrounds, white cards, soft shadows. The exact hex values come from
/// the product spec so the implementation matches the mockups.
class AppColors {
  AppColors._();

  // --- Brand / spec palette ---
  static const Color primaryBlue = Color(0xFF1479FF);
  static const Color textBlueDark = Color(0xFF123B7A);
  static const Color missionYellow = Color(0xFFFFC928);
  static const Color progressGreen = Color(0xFF34C759);
  static const Color mint = Color(0xFF7EF0C3);
  static const Color stopRed = Color(0xFFFF5A5F);
  static const Color bgLight = Color(0xFFF5FBFF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF6B7280);

  // --- Semantic roles ---
  static const Color seed = primaryBlue;
  static const Color surface = bgLight;
  static const Color onSurface = textBlueDark;
  static const Color onSurfaceMuted = textSecondary;

  // --- Game accents (mapped to the spec palette) ---
  static const Color gameBlue = primaryBlue;
  static const Color gameYellow = missionYellow;
  static const Color gameGreen = progressGreen;
  static const Color gamePurple = Color(0xFF9B6BF0);
  static const Color gameOrange = Color(0xFFFF9F45);
  static const Color errorReal = stopRed;

  // --- Glass overlays drawn over the camera (mission screen) ---
  static const Color glassFill = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x22123B7A);

  // --- Bounding-box styles (DetectionOverlayPainter) ---
  static const Color boxTarget = missionYellow;
  static const Color boxSecondary = progressGreen;
  static const Color boxDoubtful = Color(0x8834C759);
  static const Color boxConfirmed = progressGreen;

  // --- Status indicators ---
  static const Color statusReady = progressGreen;
  static const Color statusPaused = missionYellow;
  static const Color statusBusy = missionYellow;
  static const Color statusError = stopRed;

  // --- Phase 4 candidate-review palette (still used by review panel) ---
  static const Color candidatePending = missionYellow;
  static const Color candidateConfirmed = progressGreen;
  static const Color candidateNotToy = Color(0xFF8A93A8);
  static const Color candidateUnsure = gameOrange;
  static const Color candidateIgnoredAuto = Color(0x668A93A8);

  // --- Legacy aliases kept so older widgets compile ---
  static const Color boxToy = boxSecondary;
  static const Color boxCounted = boxConfirmed;
  static const Color badgeBg = Color(0x1A1479FF);
}
