import 'package:flutter/material.dart';

import '../components/primary_action_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
    final message = permanentlyDenied
        ? 'La cámara está bloqueada. Actívala para Toy Vision en los ajustes '
            'de tu dispositivo y vuelve a intentar. No se guarda ni se sube '
            'ningún video.'
        : 'Toy Vision usa la cámara solo para ver los juguetes en tu '
            'dispositivo. No se guarda ni se sube ningún video.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              size: 48,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Necesito ver tus juguetes',
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryActionButton(
              label: permanentlyDenied ? 'Intentar otra vez' : 'Activar cámara',
              color: AppColors.primaryBlue,
              leading: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: onRequestPermission,
            ),
          ],
        ),
      ),
    );
  }
}
