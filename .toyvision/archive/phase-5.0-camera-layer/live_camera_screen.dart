import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../../app/app_theme.dart';
import '../../business/live_detection_state.dart';
import '../../business/review/candidate_review_controller.dart';
import '../../storage/in_memory_scan_history_repository.dart';
import '../../storage/saved_scan_summary.dart';
import '../../ui/components/app_icon_button.dart';
import '../../ui/components/app_status_chip.dart';
import '../../ui/components/detector_mode_chip.dart';
import '../../ui/components/object_assist_banner.dart';
import '../../ui/components/privacy_notice.dart';
import '../../ui/overlays/detection_overlay_painter.dart';
import '../../ui/panels/candidate_review_summary_chip.dart';
import '../../ui/panels/live_counter_panel.dart';
import '../../ui/panels/review_panel.dart';
import '../../ui/panels/toy_summary_panel.dart';
import '../../ui/states/camera_permission_view.dart';
import '../../ui/states/empty_detection_hint.dart';
import '../../ui/states/model_loading_view.dart';
import '../live_detection_controller.dart';
import '../models/camera_status.dart';
import '../services/camera_controller_service.dart';

/// The live detection screen. Renders prepared state only: no throttling,
/// detection, counting, IoU, validation, tracking, or detector selection
/// happens here. App lifecycle changes are forwarded to the controller so the
/// camera is released when backgrounded.
class LiveCameraScreen extends ConsumerStatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  ConsumerState<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends ConsumerState<LiveCameraScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    ref
        .read(liveDetectionControllerProvider.notifier)
        .handleAppLifecycle(lifecycle);
  }

  @override
  Widget build(BuildContext context) {
    final cameraStatus = ref.watch(cameraStatusProvider);

    return Scaffold(
      body: switch (cameraStatus) {
        CameraStatus.initial ||
        CameraStatus.initializing =>
          const ModelLoadingView(message: 'Starting camera…'),
        CameraStatus.permissionDenied => CameraPermissionView(
            onRequestPermission: () =>
                ref.read(cameraStatusProvider.notifier).requestPermission(),
          ),
        CameraStatus.permissionPermanentlyDenied => CameraPermissionView(
            permanentlyDenied: true,
            onRequestPermission: () =>
                ref.read(cameraStatusProvider.notifier).requestPermission(),
          ),
        CameraStatus.error => const ModelLoadingView(
            isError: true,
            message: 'Camera unavailable',
          ),
        CameraStatus.disposed => const ModelLoadingView(),
        CameraStatus.ready ||
        CameraStatus.streaming ||
        CameraStatus.paused =>
          const _LiveDetectionView(),
      },
    );
  }
}

class _LiveDetectionView extends ConsumerWidget {
  const _LiveDetectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveDetectionControllerProvider);
    final reviewState = ref.watch(candidateReviewControllerProvider);
    final controller = ref.read(liveDetectionControllerProvider.notifier);
    final cameraController = ref.read(cameraStatusProvider.notifier).controller;

    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CameraPreviewCover(controller: cameraController),
          Positioned.fill(
            child: CustomPaint(
              painter: DetectionOverlayPainter(
                toys: state.visibleToys,
                candidatesById: reviewState.byId,
              ),
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

/// Renders the real camera preview, scaled to cover the screen. Falls back to a
/// neutral background if the controller is momentarily unavailable.
class _CameraPreviewCover extends StatelessWidget {
  const _CameraPreviewCover({required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final previewSize = c?.value.previewSize;
    if (c == null || !c.value.isInitialized || previewSize == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(c),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveCounterPanel(total: state.totalCount),
              const SizedBox(height: AppSpacing.sm),
              const CandidateReviewSummaryChip(),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppStatusChip(label: label, kind: kind),
              const SizedBox(height: AppSpacing.sm),
              const DetectorModeChip(),
            ],
          ),
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
      bottom: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ObjectAssistBanner(),
          const SizedBox(height: AppSpacing.sm),
          if (!state.hasVisibleToys && !state.isPaused) ...[
            const EmptyDetectionHint(),
            const SizedBox(height: AppSpacing.sm),
          ],
          ToySummaryPanel(summary: state.summary),
          const SizedBox(height: AppSpacing.sm),
          const PrivacyNotice(),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.state, required this.controller});

  final LiveDetectionState state;
  final LiveDetectionController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSave = state.totalCount > 0;
    final reviewState = ref.watch(candidateReviewControllerProvider);
    final hasCandidates = reviewState.all.isNotEmpty;
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: AppSpacing.lg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          AppIconButton(
            icon: Icons.history,
            tooltip: 'Saved scans',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.history),
          ),
          AppIconButton(
            icon: Icons.fact_check_outlined,
            tooltip: hasCandidates
                ? 'Review candidates (${reviewState.summary.needsReview} pending)'
                : 'Review candidates (none yet)',
            onPressed:
                hasCandidates ? () => ReviewPanel.show(context) : null,
          ),
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
          AppIconButton(
            icon: Icons.save_alt,
            tooltip: canSave ? 'Save summary' : 'Save summary (count is 0)',
            emphasized: true,
            onPressed: canSave ? () => _save(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final liveState = ref.read(liveDetectionControllerProvider);
    if (liveState.totalCount == 0) return;
    final mode = ref.read(toyDetectorModeProvider);
    final now = DateTime.now();
    final summary = SavedScanSummary(
      id: now.millisecondsSinceEpoch.toString(),
      createdAt: now,
      totalToys: liveState.totalCount,
      perCategory: Map<String, int>.from(liveState.summary.perCategory),
      detectorMode: mode.name,
    );
    await ref.read(scanHistoryProvider.notifier).save(summary);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Summary saved · ${summary.totalToys} toys'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.history),
        ),
      ),
    );
  }
}
