import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'app_glass_panel.dart';

/// Always-visible privacy reminder for the live screen.
///
/// Communicates the non-negotiable privacy posture: toys only, on-device, no
/// video saved or uploaded, people ignored.
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.onSurfaceMuted),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Toys only. Runs on your device. No video saved or uploaded. People are ignored.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}
