import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../components/app_button.dart';

/// Shown when camera permission has not been granted.
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView({super.key, required this.onRequestPermission});

  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text('Camera access needed', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ToyVision uses the camera only to detect toys on your device. '
              'No video is saved or uploaded.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Allow camera',
              icon: Icons.check,
              onPressed: onRequestPermission,
            ),
          ],
        ),
      ),
    );
  }
}
