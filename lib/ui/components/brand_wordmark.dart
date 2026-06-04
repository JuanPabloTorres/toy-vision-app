import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The two-tone "Toy Vision" wordmark — "Toy" in brand blue, "Vision" in
/// mission yellow. Both the splash hero and the home header render it, so it
/// lives here as one component sized per placement (no forked RichText).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    required this.fontSize,
    this.textAlign = TextAlign.center,
  });

  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = AppTypography.wordmark.copyWith(fontSize: fontSize);
    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Toy ',
            style: base.copyWith(color: AppColors.primaryBlue),
          ),
          TextSpan(
            text: 'Vision',
            style: base.copyWith(color: AppColors.missionYellow),
          ),
        ],
      ),
    );
  }
}
