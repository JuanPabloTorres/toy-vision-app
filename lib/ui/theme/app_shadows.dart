import 'package:flutter/material.dart';

/// Elevation tokens. Soft, never harsh — Mateo's UI sits over a camera
/// preview, so heavy shadows would look out of place.
class AppShadows {
  AppShadows._();

  // Soft, rounded elevation that hugs the card. A low-alpha brand-blue tint
  // with a wide blur and NEGATIVE spread keeps the shadow inside the card's
  // footprint, so it reads as a gentle lift — never the hard "gray square"
  // a dark, tight, zero-spread shadow produces behind rounded buttons.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x14123B7A), // ~8% brand blue
      blurRadius: 22,
      offset: Offset(0, 8),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> floatingBubble = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> celebrationGlow = [
    BoxShadow(
      color: Color(0x99FFC857),
      blurRadius: 32,
      spreadRadius: 4,
    ),
  ];
}

class AppOpacity {
  AppOpacity._();

  /// Opacity of translucent panels rendered over the camera preview.
  static const double glassPanel = 0.6;

  /// Fill opacity used inside detection bounding boxes.
  static const double boxFill = 0.18;
}

class AppDurations {
  AppDurations._();

  // Child-facing touch feedback should be perceptible without feeling slow.
  // The visual design specification defines a 180-250 ms range.
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration celebrate = Duration(milliseconds: 600);
}
