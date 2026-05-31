import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../business/live_detection_state.dart';
import '../components/app_badge.dart';
import '../components/app_glass_panel.dart';

/// Per-category count summary. Renders prepared summary data only.
///
/// Compact, single-row, horizontally scrollable — keeps the camera area
/// unblocked even when many categories have been counted.
class ToySummaryPanel extends StatelessWidget {
  const ToySummaryPanel({super.key, required this.summary});

  final ToyCountSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.perCategory.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = summary.perCategory.entries.toList(growable: false);
    return AppGlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              AppBadge(label: entries[i].key, value: '${entries[i].value}'),
              if (i < entries.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
