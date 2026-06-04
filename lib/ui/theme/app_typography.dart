import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography tokens for Toy Cleanup YOLO. Heavier weights and bigger sizes
/// than a typical adult app — Mateo needs to read at arm's length, in
/// motion, over a moving camera background.
class AppTypography {
  AppTypography._();

  /// Two-tone "Toy Vision" brand wordmark base. Size is set per placement
  /// (splash hero vs. home header) via `copyWith(fontSize: …)`; the weight
  /// and tight line-height live here so every wordmark matches.
  static const TextStyle wordmark = TextStyle(
    fontWeight: FontWeight.w900,
    height: 1.0,
  );

  /// Mission title: "Misión: recoge tus juguetes"
  static const TextStyle missionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
    color: AppColors.onSurface,
  );

  /// Big progress count: "3 / 7"
  static const TextStyle progressCount = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.onSurface,
    height: 1.0,
  );

  /// Small label next to the progress count.
  static const TextStyle progressLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurfaceMuted,
    letterSpacing: 0.6,
  );

  /// Coach bubble main message ("Veo 5 juguetes…").
  static const TextStyle coachMessage = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
    height: 1.25,
  );

  /// Mascot name label ("Tobi dice").
  static const TextStyle coachName = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.gameBlue,
    letterSpacing: 0.8,
  );

  /// Primary action button label ("Empezar misión", "Nueva misión").
  static const TextStyle buttonPrimary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    color: AppColors.onSurface,
  );

  /// Status chip text ("Detectando", "Pausa").
  static const TextStyle statusChip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  /// Mission complete celebration headline.
  static const TextStyle celebrationHeadline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.onSurface,
    letterSpacing: -0.2,
  );

  /// Quiet copy used in the parent-controls sheet rows.
  static const TextStyle parentLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurfaceMuted,
  );

  static const TextStyle parentValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );
}
