import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../components/app_button.dart';

/// Shown when camera permission has not been granted.
///
/// When [permanentlyDenied] is true the user must enable the camera in system
/// settings, so the retry affordance is framed accordingly.
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView({
    super.key,
    required this.onRequestPermission,
    this.permanentlyDenied = false,
  });

  final VoidCallback onRequestPermission;
  final bool permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = permanentlyDenied
        ? 'Camera access is blocked. Enable the camera for ToyVision in your '
            'device settings, then try again. No video is saved or uploaded.'
        : 'ToyVision uses the camera only to detect toys on your device. '
            'No video is saved or uploaded.';
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
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.onSurfaceMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: permanentlyDenied ? 'Try again' : 'Allow camera',
              icon: Icons.check,
              onPressed: onRequestPermission,
            ),
          ],
        ),
      ),
    );
  }
}
