import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../application/cleanup/cleanup_controller.dart';
import '../../application/cleanup/cleanup_state.dart';
import '../../application/feedback/audio_feedback_service.dart';
import '../../infrastructure/camera/yolo_streaming_frame_adapter.dart';
import '../../infrastructure/feedback/cleanup_feedback_coordinator.dart';
import '../../infrastructure/performance/device_health_service.dart';
import '../../infrastructure/sensors/device_motion_service.dart';
import '../../infrastructure/tflite/yolo_model_config.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/primary_action_button.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radii.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../widgets/domain_lottie_effect.dart';
import '../widgets/tobi_3d_stage.dart';
import 'developer_vision_overlay.dart';
import 'toy_halo_layer.dart';
import 'vision_display_mode.dart';

final cameraSurfaceEnabledProvider = Provider<bool>((ref) => true);

class CameraGameScreen extends ConsumerStatefulWidget {
  const CameraGameScreen({super.key});

  @override
  ConsumerState<CameraGameScreen> createState() => _CameraGameScreenState();
}

@Deprecated('Use CameraGameScreen; this is the same continuous camera game.')
class CleanupScreen extends CameraGameScreen {
  const CleanupScreen({super.key});
}

class _CameraGameScreenState extends ConsumerState<CameraGameScreen>
    with WidgetsBindingObserver {
  final YOLOViewController _yoloController = YOLOViewController();
  final YoloStreamingFrameAdapter _frameAdapter =
      const YoloStreamingFrameAdapter();
  final DeviceHealthService _deviceHealth = const AndroidDeviceHealthService();
  final DeviceMotionService _deviceMotion = const AndroidDeviceMotionService();
  late final AudioFeedbackService _audio;
  Timer? _healthTimer;
  int _cameraEpoch = 0;
  int _targetFps = 8;
  bool _nativeOverlaysHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = ref.read(audioFeedbackServiceProvider);
    ref.read(cleanupFeedbackCoordinatorProvider);
    unawaited(_deviceMotion.start());
    _pollDeviceHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollDeviceHealth(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthTimer?.cancel();
    unawaited(_deviceMotion.stop());
    _stopAllAudio();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      if (ref.read(cleanupControllerProvider).phase != CleanupPhase.completed) {
        unawaited(_deviceMotion.start());
      }
      ref.read(cleanupControllerProvider.notifier).resume();
      setState(() {
        _cameraEpoch += 1;
        _nativeOverlaysHidden = false;
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_deviceMotion.stop());
      ref.read(cleanupControllerProvider.notifier).pause();
    }
  }

  Future<void> _pollDeviceHealth() async {
    final health = await _deviceHealth.read();
    if (!mounted) return;
    ref.read(cleanupControllerProvider.notifier).updateDeviceHealth(health);
  }

  @override
  Widget build(BuildContext context) {
    final cleanup = ref.watch(cleanupControllerProvider);
    final config = ref.watch(resolvedYoloConfigProvider);
    final cameraEnabled = ref.watch(cameraSurfaceEnabledProvider);
    final visionMode = ref.watch(visionDisplayModeProvider);
    final showCamera = cleanup.phase == CleanupPhase.ready ||
        cleanup.phase == CleanupPhase.discovering ||
        cleanup.phase == CleanupPhase.cleaning ||
        cleanup.phase == CleanupPhase.verifyingRemoval ||
        cleanup.phase == CleanupPhase.verifyingRoom ||
        cleanup.phase == CleanupPhase.paused;
    ref.listen<CleanupState>(cleanupControllerProvider, (previous, next) {
      if (previous?.phase != next.phase) {
        if (next.phase == CleanupPhase.completed) {
          unawaited(_deviceMotion.stop());
        } else if (previous?.phase == CleanupPhase.completed) {
          unawaited(_deviceMotion.start());
        }
      }
      final target = next.metrics?.targetInferenceFps;
      if (target != null && target != _targetFps) {
        _targetFps = target;
        _yoloController.setStreamingConfig(_streamingConfig(target));
      }
    });
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _resetSession();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraEnabled && showCamera)
              config.when(
                data: (value) => YOLOView(
                  key: ValueKey('hybrid-camera-$_cameraEpoch'),
                  modelPath: value.modelPath,
                  task: value.task,
                  controller: _yoloController,
                  cameraResolution: value.cameraResolution,
                  confidenceThreshold: value.confidenceThreshold,
                  iouThreshold: value.iouThreshold,
                  useGpu: value.useGpu,
                  lensFacing: LensFacing.back,
                  streamingConfig: _streamingConfig(_targetFps),
                  onStreamingData: _onStreamingData,
                  onModelLoad: (_, __) {
                    unawaited(_hideNativeOverlays());
                    ref
                        .read(cleanupControllerProvider.notifier)
                        .markModelReady();
                  },
                  onModelError: (error, message, _) {
                    ref
                        .read(cleanupControllerProvider.notifier)
                        .markModelError('$message: $error');
                  },
                ),
                loading: () => const ColoredBox(color: Colors.black),
                error: (error, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ref
                        .read(cleanupControllerProvider.notifier)
                        .markModelError(error.toString());
                  });
                  return const ColoredBox(color: Colors.black);
                },
              )
            else
              cleanup.phase == CleanupPhase.ready
                  ? const ToyBackground(
                      safeArea: false,
                      child: SizedBox.expand(),
                    )
                  : const ColoredBox(color: Colors.black),
            if (visionMode == VisionDisplayMode.kid &&
                cleanup.worldModel != null &&
                cleanup.metrics != null)
              ToyHaloLayer(
                tracks: cleanup.worldModel!.activeTracks.values,
                sourceWidth: cleanup.metrics!.sourceWidth,
                sourceHeight: cleanup.metrics!.sourceHeight,
                activeTrackId: cleanup.activeTargetTrackId,
              ),
            if (visionMode == VisionDisplayMode.developerDebug &&
                cleanup.latestPerception != null)
              DeveloperVisionOverlay(
                result: cleanup.latestPerception!,
                phase: cleanup.phase,
                activeToyId: cleanup.activeTargetTrackId,
                completionEvidence: cleanup.completionEvidence,
              ),
            _CleanupChrome(
              state: cleanup,
              onLeave: _leave,
              onRetry: _retry,
              onBeginDiscovery: () =>
                  ref.read(cleanupControllerProvider.notifier).beginDiscovery(),
              onReplay: () =>
                  ref.read(cleanupControllerProvider.notifier).start(),
            ),
          ],
        ),
      ),
    );
  }

  YOLOStreamingConfig _streamingConfig(int targetFps) =>
      YOLOStreamingConfig.custom(
        includeDetections: true,
        includeProcessingTimeMs: true,
        includeFps: true,
        includeOriginalImage: true,
        maxFPS: targetFps,
        inferenceFrequency: targetFps,
      );

  Future<void> _onStreamingData(Map<String, dynamic> payload) async {
    try {
      if (!_nativeOverlaysHidden) unawaited(_hideNativeOverlays());
      final spatial = await _deviceMotion.readLatest();
      if (!mounted) return;
      final frame = _frameAdapter.adapt(payload, spatial: spatial);
      final controller = ref.read(cleanupControllerProvider.notifier);
      controller.markModelReady();
      unawaited(controller.ingest(frame));
    } on CameraFrameAdapterException catch (error) {
      if (kDebugMode) debugPrint(error.toString());
    }
  }

  Future<void> _hideNativeOverlays() async {
    if (_nativeOverlaysHidden) return;
    for (var attempt = 0; attempt < 20 && mounted; attempt++) {
      if (_yoloController.isInitialized) {
        await _yoloController.setShowOverlays(false);
        _nativeOverlaysHidden = true;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  void _retry() {
    ref.read(cleanupControllerProvider.notifier).start();
    setState(() {
      _cameraEpoch += 1;
      _nativeOverlaysHidden = false;
    });
  }

  void _leave() {
    _resetSession();
    Navigator.of(context).pop();
  }

  void _resetSession() {
    _stopAllAudio();
    ref.read(cleanupControllerProvider.notifier).reset();
  }

  void _stopAllAudio() {
    unawaited(
      Future.wait([
        _audio.stop(AudioChannel.music),
        _audio.stop(AudioChannel.effects),
        _audio.stop(AudioChannel.voice),
      ]),
    );
  }
}

class _CleanupChrome extends ConsumerWidget {
  const _CleanupChrome({
    required this.state,
    required this.onLeave,
    required this.onRetry,
    required this.onBeginDiscovery,
    required this.onReplay,
  });

  final CleanupState state;
  final VoidCallback onLeave;
  final VoidCallback onRetry;
  final VoidCallback onBeginDiscovery;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.phase == CleanupPhase.completed) {
      return _CelebrationView(
        state: state,
        onFinish: onLeave,
        onReplay: onReplay,
      );
    }
    if (state.phase == CleanupPhase.error) {
      return _ErrorView(
        message: state.message,
        onRetry: onRetry,
        onLeave: onLeave,
      );
    }
    if (state.phase == CleanupPhase.ready) {
      return _PreparationView(
        onBeginScan: onBeginDiscovery,
        onLeave: onLeave,
      );
    }
    if (state.phase == CleanupPhase.discovering) {
      return _DiscoveryView(state: state, onLeave: onLeave);
    }
    return SafeArea(
      child: Stack(
        children: [
          const Positioned.fill(child: DomainLottieEffect()),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            child: _VisionHeader(
              phase: state.phase,
              onLeave: onLeave,
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.lg,
            child: _VisionCoachCard(state: state),
          ),
        ],
      ),
    );
  }
}

class _PreparationView extends StatelessWidget {
  const _PreparationView({
    required this.onBeginScan,
    required this.onLeave,
  });

  final VoidCallback onBeginScan;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => ToyBackground(
        safeArea: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ToyScreenHeader(title: '¡Vamos a recoger!', onBack: onLeave),
              const SizedBox(height: AppSpacing.md),
              const ToyPageHero(
                mascot: Tobi3dStage(enable3d: false, fallbackSize: 108),
                message:
                    '¿Listo para ayudarme? Mira el cuarto con calma y yo encontraré las cosas por recoger.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _PreparationTips(),
              const SizedBox(height: AppSpacing.xl),
              PrimaryActionButton(
                key: const Key('begin-room-scan'),
                label: 'ESTOY LISTO',
                color: AppColors.actionGreen,
                pulse: true,
                onPressed: onBeginScan,
                leading: const AppImage(
                  assetPath: AppAssets.scanIcon,
                  fallbackIcon: Icons.center_focus_strong_rounded,
                  fallbackColor: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PreparationTips extends StatelessWidget {
  const _PreparationTips();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const tips = [
            _PreparationTip(
              icon: Icons.light_mode_rounded,
              assetPath: AppAssets.cameraIcon,
              title: 'Buena luz',
            ),
            _PreparationTip(
              icon: Icons.panorama_wide_angle_rounded,
              assetPath: AppAssets.scanIcon,
              title: 'Mira el cuarto',
            ),
            _PreparationTip(
              icon: Icons.slow_motion_video_rounded,
              assetPath: AppAssets.targetIcon,
              title: 'Ve despacio',
            ),
          ];
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tip in tips) ...[
                  tip,
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < tips.length; index++) ...[
                Expanded(child: tips[index]),
                if (index < tips.length - 1)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          );
        },
      );
}

class _PreparationTip extends StatelessWidget {
  const _PreparationTip({
    required this.icon,
    required this.assetPath,
    required this.title,
  });

  final IconData icon;
  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) => ToyCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            AppImage(
              assetPath: assetPath,
              fallbackIcon: icon,
              fallbackColor: AppColors.primaryBlue,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textBlueDark,
              ),
            ),
          ],
        ),
      );
}

class _DiscoveryView extends StatelessWidget {
  const _DiscoveryView({required this.state, required this.onLeave});

  final CleanupState state;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.sm,
              child: _VisionHeader(
                phase: state.phase,
                onLeave: onLeave,
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: _VisionCoachCard(state: state),
            ),
          ],
        ),
      );
}

class _VisionHeader extends StatelessWidget {
  const _VisionHeader({required this.phase, required this.onLeave});

  final CleanupPhase phase;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.96),
            shape: const CircleBorder(),
            elevation: 4,
            child: IconButton(
              key: const Key('leave-cleanup'),
              tooltip: 'Volver al inicio',
              onPressed: onLeave,
              icon: const AppImage(
                assetPath: AppAssets.backIcon,
                fallbackIcon: Icons.arrow_back_rounded,
                size: 34,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _VisionJourneyBar(phase: phase)),
        ],
      );
}

class _VisionJourneyBar extends StatelessWidget {
  const _VisionJourneyBar({required this.phase});

  final CleanupPhase phase;

  @override
  Widget build(BuildContext context) {
    final activeIndex = switch (phase) {
      CleanupPhase.discovering => 0,
      CleanupPhase.cleaning || CleanupPhase.verifyingRemoval => 1,
      CleanupPhase.verifyingRoom || CleanupPhase.completed => 2,
      _ => 0,
    };
    const steps = [
      (AppAssets.searchIcon, Icons.search_rounded, 'Encontrar'),
      (AppAssets.collectedIcon, Icons.inventory_2_rounded, 'Recoger'),
      (AppAssets.emptyRoomIcon, Icons.auto_awesome_rounded, 'Confirmar'),
    ];
    return ToyCard(
      color: Colors.white.withValues(alpha: 0.96),
      padding: const EdgeInsets.all(AppSpacing.xs),
      borderColor: AppColors.overlayCyan.withValues(alpha: 0.72),
      child: Row(
        children: [
          for (var index = 0; index < steps.length; index++) ...[
            Expanded(
              child: _VisionJourneyStep(
                assetPath: steps[index].$1,
                fallbackIcon: steps[index].$2,
                label: steps[index].$3,
                active: index == activeIndex,
                complete: index < activeIndex,
              ),
            ),
            if (index < steps.length - 1)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: index < activeIndex
                    ? AppColors.actionGreen
                    : AppColors.textSecondary,
              ),
          ],
        ],
      ),
    );
  }
}

class _VisionJourneyStep extends StatelessWidget {
  const _VisionJourneyStep({
    required this.assetPath,
    required this.fallbackIcon,
    required this.label,
    required this.active,
    required this.complete,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.surfaceSoft
              : complete
                  ? AppColors.actionGreen.withValues(alpha: 0.10)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: active
              ? Border.all(
                  color: AppColors.primaryBlue.withValues(alpha: 0.28),
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppImage(
              assetPath: complete ? AppAssets.confirmedIcon : assetPath,
              fallbackIcon:
                  complete ? Icons.check_circle_rounded : fallbackIcon,
              fallbackColor:
                  complete ? AppColors.actionGreen : AppColors.primaryBlue,
              size: 30,
            ),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: AppTypography.caption.copyWith(
                  color: active
                      ? AppColors.primaryBlue
                      : complete
                          ? AppColors.actionGreen
                          : AppColors.textSecondary,
                  fontWeight:
                      active || complete ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _VisionCoachCard extends StatelessWidget {
  const _VisionCoachCard({required this.state});

  final CleanupState state;

  @override
  Widget build(BuildContext context) {
    late final String assetPath;
    late final IconData fallbackIcon;
    late final String title;
    late final String body;
    late final Color accent;
    double? progress;

    switch (state.phase) {
      case CleanupPhase.discovering:
        assetPath = AppAssets.searchIcon;
        fallbackIcon = Icons.search_rounded;
        title = state.modelReady
            ? 'Encuentra las cosas por recoger'
            : 'Preparando la visión…';
        final found = state.discoveryProgress.stableToyCount;
        body = found == 0
            ? 'Mueve la cámara despacio y mantén visible el suelo.'
            : '$found ${found == 1 ? 'objeto encontrado' : 'objetos encontrados'}. Sigue recorriendo el cuarto.';
        accent = AppColors.primaryBlue;
        progress = state.discoveryProgress.coverageEstimate;
      case CleanupPhase.verifyingRemoval:
        assetPath = AppAssets.confirmedIcon;
        fallbackIcon = Icons.fact_check_rounded;
        title = 'Comprobando el lugar';
        final targetId = state.activeTargetTrackId;
        final evidence = targetId == null
            ? null
            : state.latestPerception?.disappearanceEvidence[targetId];
        if (evidence == null) {
          body = 'Mantén visible el lugar donde estaba el juguete.';
          progress = 0;
        } else {
          final frameProgress = (evidence.missingFrames / 8).clamp(0.0, 1.0);
          final timeProgress =
              (evidence.missingDuration.inMilliseconds / 1500).clamp(0.0, 1.0);
          progress =
              frameProgress < timeProgress ? frameProgress : timeProgress;
          if (!evidence.interactionObserved) {
            body =
                'Recógelo despacio dentro del cuadro para que Tobi vea el movimiento.';
          } else if (!evidence.stableSceneWindow) {
            body = 'Mantén la cámara quieta un momento.';
          } else if (!evidence.regionReobserved) {
            body = 'Apunta al lugar vacío donde estaba el juguete.';
          } else if (evidence.reidentificationCandidate) {
            body = 'Todavía veo algo parecido. Despeja esa zona.';
          } else {
            body = 'Confirmando que el lugar quedó vacío…';
          }
        }
        accent = AppColors.missionYellow;
      case CleanupPhase.verifyingRoom:
        assetPath = AppAssets.emptyRoomIcon;
        fallbackIcon = Icons.auto_awesome_rounded;
        title = '¡Una última mirada!';
        body = state.completionEvidence?.guidance ??
            'Mueve la cámara despacio para confirmar que no queda ningún juguete.';
        accent = AppColors.gamePurple;
        progress = state.completionEvidence?.sceneCoverage ?? 0;
      case CleanupPhase.cleaning:
        assetPath = state.activeTargetTrackId == null
            ? AppAssets.searchIcon
            : AppAssets.targetIcon;
        fallbackIcon = state.activeTargetTrackId == null
            ? Icons.search_rounded
            : Icons.center_focus_strong_rounded;
        title = state.activeTargetTrackId == null
            ? 'Busca el siguiente juguete'
            : 'Recoge el juguete brillante';
        body = '${state.collected} guardados · '
            '${state.remainingEstimate} por guardar';
        accent = AppColors.actionGreen;
      default:
        assetPath = AppAssets.scanIcon;
        fallbackIcon = Icons.center_focus_strong_rounded;
        title = state.message;
        body = 'Sigue las indicaciones de Tobi.';
        accent = AppColors.primaryBlue;
    }

    return ToyCard(
      color: Colors.white.withValues(alpha: 0.96),
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: accent.withValues(alpha: 0.72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 78,
                height: 84,
                child: Tobi3dStage(enable3d: false, fallbackSize: 74),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppImage(
                          assetPath: assetPath,
                          fallbackIcon: fallbackIcon,
                          fallbackColor: accent,
                          size: 34,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.cardTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(body, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: 'Progreso ${(progress * 100).round()} por ciento',
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 9,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.all(Radius.circular(9)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CelebrationView extends StatelessWidget {
  const _CelebrationView({
    required this.state,
    required this.onFinish,
    required this.onReplay,
  });
  final CleanupState state;
  final VoidCallback onFinish;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return ToyBackground(
      safeArea: false,
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: DomainLottieEffect()),
            SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 230,
                        width: 260,
                        child: Tobi3dStage(enable3d: false, fallbackSize: 200),
                      ),
                      const Text(
                        '¡HABITACIÓN LIMPIA!',
                        textAlign: TextAlign.center,
                        style: AppTypography.celebrationHeadline,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ToyCard(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppImage(
                              assetPath: AppAssets.trophyIcon,
                              fallbackIcon: Icons.inventory_2_rounded,
                              fallbackColor: AppColors.gamePurple,
                              size: 34,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${state.collected} recogidos',
                              style: AppTypography.bodyStrong,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            const AppImage(
                              assetPath: AppAssets.starIcon,
                              fallbackIcon: Icons.star_rounded,
                              fallbackColor: AppColors.missionYellow,
                              size: 32,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '+${state.collected}',
                              style: AppTypography.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryActionButton(
                        key: const Key('finish-celebration'),
                        label: 'VOLVER AL INICIO',
                        color: AppColors.actionGreen,
                        onPressed: onFinish,
                        leading: const AppImage(
                          assetPath: AppAssets.homeIcon,
                          fallbackIcon: Icons.home_rounded,
                          fallbackColor: Colors.white,
                          size: 30,
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('replay-cleanup'),
                        onPressed: onReplay,
                        icon: const AppImage(
                          assetPath: AppAssets.replayIcon,
                          fallbackIcon: Icons.replay_rounded,
                          size: 26,
                        ),
                        label: const Text('Recoger otra vez'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onLeave,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ToyBackground(
      safeArea: false,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ToyStateCard(
                icon: Icons.visibility_off_rounded,
                assetPath: AppAssets.cameraIcon,
                title: 'Tobi perdió de vista el cuarto',
                message: message,
                action: Column(
                  children: [
                    PrimaryActionButton(
                      label: 'INTENTAR OTRA VEZ',
                      color: AppColors.primaryBlue,
                      onPressed: onRetry,
                    ),
                    TextButton(
                      onPressed: onLeave,
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
