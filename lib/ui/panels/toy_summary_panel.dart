import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../business/live_detection_state.dart';
import '../components/app_badge.dart';
import '../components/app_glass_panel.dart';

/// Per-category count summary. Renders prepared summary data only.
class ToySummaryPanel extends StatelessWidget {
  const ToySummaryPanel({super.key, required this.summary});

  final ToyCountSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.perCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = summary.perCategory.entries.toList();
    return AppGlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By category',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in entries)
                AppBadge(label: e.key, value: '${e.value}'),
            ],
          ),
        ],
      ),
    );
  }
}
