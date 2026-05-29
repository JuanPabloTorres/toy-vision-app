import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Small labeled badge, e.g. a per-category count chip.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textTheme.bodyMedium),
          if (value != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              value!,
              style: textTheme.labelLarge?.copyWith(color: AppColors.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}
