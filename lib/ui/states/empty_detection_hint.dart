import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../components/app_glass_panel.dart';

/// Shown while the engine is running but no toys are currently visible.
class EmptyDetectionHint extends StatelessWidget {
  const EmptyDetectionHint({super.key});

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.center_focus_weak, color: AppColors.onSurfaceMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Apunta la cámara a los juguetes.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
