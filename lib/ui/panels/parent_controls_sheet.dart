import 'package:flutter/material.dart';

import '../../business/live_detection_state.dart';
import '../../detection/yolo/yolo_model_config.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Bottom-sheet shown when the adult taps the tune icon. Surfaces the
/// technical state Mateo should never see (model status, confidence
/// threshold, raw counts) and offers adult-only actions like "reset
/// mission" outside the game flow.
///
/// Renders prepared state only; emits user intents via callbacks so the
/// controller stays the source of truth.
class ParentControlsSheet extends StatelessWidget {
  const ParentControlsSheet({
    super.key,
    required this.state,
    required this.modelConfig,
    required this.onResetMission,
    required this.onClose,
  });

  final LiveDetectionState state;
  final YoloModelConfig modelConfig;
  final VoidCallback onResetMission;
  final VoidCallback onClose;

  static Future<void> show(
    BuildContext context, {
    required LiveDetectionState state,
    required YoloModelConfig modelConfig,
    required VoidCallback onResetMission,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => ParentControlsSheet(
        state: state,
        modelConfig: modelConfig,
        onResetMission: () {
          Navigator.of(ctx).pop();
          onResetMission();
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceMuted,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Modo padre',
            style: AppTypography.missionTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Información técnica del detector y controles ocultos al niño.',
            style: AppTypography.parentLabel,
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Row('Detector', 'YOLO on-device'),
          _Row('Modelo', modelConfig.modelPath),
          _Row('Resolución', modelConfig.cameraResolution),
          _Row(
            'Confianza mínima',
            modelConfig.confidenceThreshold.toStringAsFixed(2),
          ),
          _Row('IoU NMS', modelConfig.iouThreshold.toStringAsFixed(2)),
          _Row('Estado del modelo', _modelStatusLabel(state.status)),
          _Row('Misión', _missionStatusLabel(state.missionStatus.name)),
          _Row('Visibles ahora', '${state.visibleToys.length}'),
          _Row('Acumulado sesión', '${state.totalCount}'),
          _Row(
            'Progreso',
            state.knownToyCount > 0
                ? '${state.collectedToyCount} / ${state.knownToyCount} recogidos'
                : '—',
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: onResetMission,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reiniciar misión'),
            style: AppButtonStyles.outlined(color: AppColors.gamePurple),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onClose,
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static String _modelStatusLabel(ModelStatus s) {
    switch (s) {
      case ModelStatus.initializing:
        return 'inicializando';
      case ModelStatus.ready:
        return 'listo';
      case ModelStatus.error:
        return 'error';
    }
  }

  static String _missionStatusLabel(String raw) => raw;
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.parentLabel),
          Text(value, style: AppTypography.parentValue),
        ],
      ),
    );
  }
}
