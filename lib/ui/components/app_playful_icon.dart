import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';

enum AppPlayfulIconSymbol {
  childAvatar,
  missionStart,
  dailyMission,
  toyBasket,
  cameraScan,
  calendar,
  reward,
}

/// Shared child-friendly icon mapping for UI surfaces that previously used
/// decorative image assets. The robot mascot and launcher icon stay as real
/// images and are intentionally not routed through this widget.
class AppPlayfulIcon extends StatelessWidget {
  const AppPlayfulIcon({
    super.key,
    required this.symbol,
    this.size,
    this.color,
  });

  final AppPlayfulIconSymbol symbol;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PhosphorIcon(
      _iconFor(symbol),
      size: size,
      color: color ?? AppColors.primaryBlue,
    );
  }

  static PhosphorIconData _iconFor(AppPlayfulIconSymbol symbol) {
    return switch (symbol) {
      AppPlayfulIconSymbol.childAvatar =>
        PhosphorIcons.baby(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.missionStart =>
        PhosphorIcons.camera(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.dailyMission =>
        PhosphorIcons.beachBall(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.toyBasket =>
        PhosphorIcons.basket(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.cameraScan =>
        PhosphorIcons.camera(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.calendar =>
        PhosphorIcons.calendarDot(PhosphorIconsStyle.fill),
      AppPlayfulIconSymbol.reward =>
        PhosphorIcons.crown(PhosphorIconsStyle.fill),
    };
  }
}
