import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

enum AppStatusKind { ready, busy, error }

/// Status indicator chip (e.g. model/camera state). Presentation only — the
/// caller maps domain status to an [AppStatusKind].
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.label, required this.kind});

  final String label;
  final AppStatusKind kind;

  Color get _color => switch (kind) {
        AppStatusKind.ready => AppColors.statusReady,
        AppStatusKind.busy => AppColors.statusBusy,
        AppStatusKind.error => AppColors.statusError,
      };

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
