import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../components/app_glass_panel.dart';

/// Displays the total stable toy count. Renders a prepared value only.
class LiveCounterPanel extends StatelessWidget {
  const LiveCounterPanel({super.key, required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppGlassPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toys counted',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('$total', style: textTheme.headlineMedium),
        ],
      ),
    );
  }
}
