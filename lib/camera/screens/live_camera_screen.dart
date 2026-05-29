import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../business/live_detection_state.dart';
import '../../ui/components/app_icon_button.dart';
import '../../ui/components/app_status_chip.dart';
import '../../ui/components/privacy_notice.dart';
import '../../ui/overlays/detection_overlay_painter.dart';
import '../../ui/panels/live_counter_panel.dart';
import '../../ui/panels/toy_summary_panel.dart';
import '../../ui/states/camera_permission_view.dart';
import '../../ui/states/empty_detection_hint.dart';
import '../../ui/states/model_loading_view.dart';
import '../live_detection_controller.dart';
import '../models/camera_status.dart';
import '../services/camera_controller_service.dart';

/// The live detection screen. It selects the correct view for the camera
/// status, then composes preview placeholder + overlay + panels + controls.
///
/// It renders prepared state only: no counting, IoU, or validity logic here.
class LiveCameraScreen extends ConsumerWidget {
  const LiveCameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraStatus = ref.watch(cameraStatusProvider);

    return Scaffold(
      body: switch (cameraStatus) {
        CameraStatus.initializing => const ModelLoadingView(),
        CameraStatus.permissionDenied => CameraPermissionView(
            onRequestPermission: () =>
                ref.read(cameraStatusProvider.notifier).requestPermission(),
          ),
        CameraStatus.error => const ModelLoadingView(
            isError: true,
            message: 'Camera unavailable',
          ),
        CameraStatus.ready => const _LiveDetectionView(),
      },
    );
  }
}

class _LiveDetectionView extends ConsumerWidget {
  const _LiveDetectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveDetectionControllerProvider);
    final controller = ref.read(liveDetectionControllerProvider.notifier);

    if (state.status == ModelStatus.error) {
      return const ModelLoadingView(isError: true);
    }
    if (state.status == ModelStatus.initializing) {
      return const ModelLoadingView();
    }

    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _PreviewPlaceholder(),
          // Detection overlay (bounding boxes for tracked toys).
          Positioned.fill(
            child: CustomPaint(
              painter: DetectionOverlayPainter(toys: state.visibleToys),
            ),
          ),
          _TopBar(state: state),
          _BottomPanels(state: state),
          _Controls(state: state, controller: controller),
        ],
      ),
    );
  }
}

/// Placeholder shown until the real camera preview is wired in Phase 2.
class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Camera preview (Phase 2)',
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final LiveDetectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, kind) = state.isPaused
        ? ('Paused', AppStatusKind.busy)
        : ('Detecting', AppStatusKind.ready);
    return Positioned(
      top: AppSpacing.lg,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LiveCounterPanel(total: state.totalCount),
          AppStatusChip(label: label, kind: kind),
        ],
      ),
    );
  }
}

class _BottomPanels extends StatelessWidget {
  const _BottomPanels({required this.state});

  final LiveDetectionState state;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.hasVisibleToys && !state.isPaused) ...[
            const EmptyDetectionHint(),
            const SizedBox(height: AppSpacing.md),
          ],
          ToySummaryPanel(summary: state.summary),
          const SizedBox(height: AppSpacing.md),
          const PrivacyNotice(),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.controller});

  final LiveDetectionState state;
  final LiveDetectionController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppIconButton(
            icon: state.isPaused ? Icons.play_arrow : Icons.pause,
            tooltip: state.isPaused ? 'Resume' : 'Pause',
            onPressed: controller.togglePause,
          ),
          AppIconButton(
            icon: Icons.refresh,
            tooltip: 'Reset count',
            onPressed: controller.reset,
          ),
          const AppIconButton(
            icon: Icons.save_alt,
            tooltip: 'Save summary (Phase 2)',
            emphasized: true,
            // Storage layer arrives in a later phase; summary-only save.
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
