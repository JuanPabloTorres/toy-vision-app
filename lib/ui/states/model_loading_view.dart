import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

/// Shown while the camera/detector is initializing or in an error state.
class ModelLoadingView extends StatelessWidget {
  const ModelLoadingView({super.key, this.isError = false, this.message});

  final bool isError;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isError)
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.statusError,
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message ??
                (isError ? 'No veo juguetes ahora.' : 'Preparando…'),
            style:
                textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}
