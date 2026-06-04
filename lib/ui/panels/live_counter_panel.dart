import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../components/app_glass_panel.dart';

/// Displays the total stable toy count and (optionally) the visible-now
/// count for the current frame. Renders a prepared value only.
class LiveCounterPanel extends StatelessWidget {
  const LiveCounterPanel({
    super.key,
    required this.total,
    this.visibleNow,
  });

  /// Cumulative count from [ToyCountingService] — total toys ever counted
  /// in this session.
  final int total;

  /// How many toys are visible in the latest processed frame. When non-null
  /// it renders next to the cumulative count so the user can see at a
  /// glance whether the camera currently sees anything.
  final int? visibleNow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppGlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Juguetes detectados',
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$total', style: textTheme.headlineMedium),
              if (visibleNow != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '· $visibleNow ahora',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
