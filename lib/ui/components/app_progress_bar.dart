import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Reusable horizontal progress bar with the game palette.
///
/// `value` is `0.0..1.0`. When `null`, renders an indeterminate animation
/// (used while we're capturing the initial mission count). Animates between
/// values so the bar visibly grows when Mateo picks up a toy.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.activeColor,
    this.trackColor,
  });

  final double? value;
  final double height;
  final Color? activeColor;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final fill = activeColor ?? AppColors.gameGreen;
    final track = trackColor ?? AppColors.glassFill;
    final clamped = value?.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: height,
        child: clamped == null
            ? LinearProgressIndicator(
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation<Color>(fill),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(color: track),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * clamped,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              fill.withValues(alpha: 0.85),
                              fill,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
