import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../business/app_audio_service.dart';
import '../../business/live_detection_state.dart';
import '../../business/mission/cleanup_mission_status.dart';
import '../../detection/yolo/yolo_model_config.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/app_playful_icon.dart';
import '../../ui/components/primary_action_button.dart';
import '../../ui/components/searching_dots.dart';
import '../../ui/navigation/app_bottom_navigation.dart';
import '../../ui/navigation/app_shell.dart';
import '../../ui/overlays/detection_overlay_painter.dart';
import '../../ui/panels/mission_complete_panel.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radii.dart';
import '../../ui/theme/app_shadows.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../controllers/toy_cleanup_controller.dart';

/// Mission tab — a kid-friendly robot guide. Automatic scan → guide one toy
/// at a time → "Ya lo recogí" → next / re-scan → "¿Ves otro juguete?" →
/// celebrate. No inspection or area-marking step; the only manual input is
/// tapping a toy the model missed (the no-toys fallback).
///
/// All decisions come from [ToyCleanupController]; this screen only renders
/// the state for the current [CleanupMissionStatus].
class ToyCleanupCameraScreen extends ConsumerStatefulWidget {
  const ToyCleanupCameraScreen({super.key});

  @override
  ConsumerState<ToyCleanupCameraScreen> createState() =>
      _ToyCleanupCameraScreenState();
}

class _ToyCleanupCameraScreenState
    extends ConsumerState<ToyCleanupCameraScreen>
    with WidgetsBindingObserver {
  final YOLOViewController _yoloController = YOLOViewController();
  String? _errorMessage;

  /// Bumped every time the app resumes from the background. It is part of the
  /// [YOLOView]'s key, so a resume forces Flutter to dispose the old (now
  /// BLACK) native camera surface and create a fresh one — fixing the
  /// "camera goes black after switching apps / locking the screen" bug, which
  /// otherwise leaves the detector with no frames (raw=0, "no veo nada").
  int _cameraEpoch = 0;

  /// Guards the one-shot celebration chime (played via AppAudioService).
  bool _playedCompletionSound = false;

  /// Captured in initState so dispose() never touches `ref` (illegal once the
  /// element is disposed).
  late final AppAudioService _audio;

  /// We hide YOLOView's NATIVE bounding-box overlay so only our own
  /// toy-only overlay is shown. The native overlay draws EVERY COCO class
  /// (person, tv, mouse, …) — exactly the non-toy boxes we must not show a
  /// child. Hiding must be retried because the native surface isn't ready
  /// the instant `onModelLoad` fires.
  bool _overlaysHidden = false;
  int _hideAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audio = ref.read(appAudioServiceProvider);
    // Entering the mission: start the fun playground loop. play() replaces the
    // Home theme on the shared player — a single op, no stop/play race.
    _audio.playMissionMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.stopMissionMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    // Coming back from the background, the native camera surface is dead
    // (black preview, no frames). Recreate the YOLOView by changing its key so
    // the detector gets a live feed again. Also re-arm the native-overlay
    // hiding, which the fresh surface needs.
    if (appState == AppLifecycleState.resumed && mounted) {
      setState(() {
        _cameraEpoch++;
        _overlaysHidden = false;
        _hideAttempts = 0;
      });
    }
  }

  void _ensureNativeOverlaysHidden() {
    if (_overlaysHidden || _hideAttempts >= 10) return;
    _hideAttempts++;
    _yoloController.setShowOverlays(false).then((_) {
      if (_hideAttempts >= 3) _overlaysHidden = true;
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(toyCleanupControllerProvider);
    final controller = ref.read(toyCleanupControllerProvider.notifier);
    final showDiagnostics =
        kDebugMode && ref.watch(missionDiagnosticsEnabledProvider);

    // Play the celebration chime EXACTLY once, on the transition into
    // `completed`. The guard survives rebuilds; it resets when a new mission
    // leaves the completed state, so the next mission can celebrate again.
    ref.listen(toyCleanupControllerProvider, (prev, next) {
      final justCompleted =
          next.missionStatus == CleanupMissionStatus.completed &&
              prev?.missionStatus != CleanupMissionStatus.completed;
      if (next.missionStatus != CleanupMissionStatus.completed) {
        _playedCompletionSound = false;
      } else if (justCompleted && !_playedCompletionSound) {
        _playedCompletionSound = true;
        ref.read(appAudioServiceProvider).playMissionComplete();
      }

      // A short happy chime whenever a toy is collected — manual OR automatic.
      // Driven off the count so both paths celebrate exactly once.
      if (next.collectedToyCount > (prev?.collectedToyCount ?? 0)) {
        _audio.playButtonSuccess();
      }
    });
    var config = ref.watch(resolvedYoloConfigProvider).valueOrNull ??
        YoloModelConfig.fallback;

    // DEBUG-ONLY: a confidence-threshold override from the Detection Recall
    // Lab. Inert in release and when unset (null) → identical to production.
    // Changing it rebuilds YOLOView via the existing camera-epoch mechanism
    // (a manual action, never per-frame — no live-loop cost).
    if (kDebugMode) {
      final override = ref.watch(debugDetectionConfidenceProvider);
      if (override != null) {
        config = config.copyWith(confidenceThreshold: override);
      }
      ref.listen<double?>(debugDetectionConfidenceProvider, (_, __) {
        setState(() => _cameraEpoch++);
      });
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: AppImage(
            assetPath: AppAssets.missionBackground,
            fallbackIcon: Icons.blur_on,
            fallbackColor: Colors.transparent,
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              children: [
                // One slim bar: back + the current step + how many are collected.
                // (The old tall status card was removed so the camera can grow.)
                _MissionTopBar(
                  title: _statusTitle(state),
                  collected: state.collectedToyCount,
                  goal: state.targetPickupGoal,
                  personalBest: state.personalBestToyCount,
                  hasReachedGoal: state.hasReachedGoal,
                  isNewRecord: state.isNewRecord,
                  onBack: () {
                    _audio.playButtonTap();
                    ref.read(appTabProvider.notifier).state = AppTab.home;
                  },
                ),
                // Coach (small robot + short message) lives ABOVE the camera so
                // it never covers the preview.
                if (state.status == ModelStatus.ready &&
                    state.guidanceMessage.isNotEmpty &&
                    state.missionStatus != CleanupMissionStatus.completed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _CoachStrip(message: state.guidanceMessage),
                ],
                const SizedBox(height: AppSpacing.sm),
                // The camera is the hero — it takes ALL the remaining space.
                Expanded(
                  child: _CameraCard(
                    config: config,
                    controller: _yoloController,
                    cameraEpoch: _cameraEpoch,
                    state: state,
                    errorMessage: _errorMessage,
                    onResult: (results) {
                      _ensureNativeOverlaysHidden();
                      controller.ingest(results);
                    },
                    onModelLoad: _handleModelLoad,
                    onModelError: _handleModelError,
                    onRetry: () =>
                        Navigator.of(context).pushReplacementNamed('/'),
                    onChildTap: controller.addChildTapToy,
                    onToggleDiagnostics: () {
                      if (!kDebugMode) return;
                      final notifier =
                          ref.read(missionDiagnosticsEnabledProvider.notifier);
                      notifier.state = !notifier.state;
                    },
                  ),
                ),
                // When the mission is complete the celebration panel (overlaid on
                // the camera card) owns both CTAs — "Ver mis estrellas" and
                // "Nueva misión" — so the bottom action row is suppressed to
                // avoid a duplicate "Nueva misión" button below the card.
                if (state.missionStatus != CleanupMissionStatus.completed) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ActionRow(
                    state: state,
                    controller: controller,
                    audio: ref.read(appAudioServiceProvider),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDiagnostics)
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: SafeArea(
              child: _MissionDiagnosticsPanel(snapshot: state.debugSnapshot),
            ),
          ),
      ],
    );
  }

  Future<void> _handleModelLoad(String modelPath, YOLOTask? task) async {
    if (kDebugMode) {
      final cfg = ref.read(resolvedYoloConfigProvider).valueOrNull;
      debugPrint(
          'MissionDX: modelLoaded=true path=$modelPath task=${task?.name} '
          'isCustomToyModel=${cfg?.isCustomToyModel} '
          'confidenceThreshold=${cfg?.confidenceThreshold} '
          'iouThreshold=${cfg?.iouThreshold} '
          'cameraResolution=${cfg?.cameraResolution}');
    }
    _overlaysHidden = false;
    _hideAttempts = 0;
    _ensureNativeOverlaysHidden();
    if (!mounted) return;
    final controller = ref.read(toyCleanupControllerProvider.notifier);
    controller.recordModelLoaded(
      ref.read(resolvedYoloConfigProvider).valueOrNull ??
          YoloModelConfig.fallback,
      loadedModelPath: modelPath,
      task: task,
    );
    controller.markModelReady();
  }

  void _handleModelError(Object error, String message, YOLOTask? task) {
    if (kDebugMode) {
      debugPrint('MissionDX: model error message=$message error=$error');
    }
    setState(() {
      _errorMessage = message.isEmpty ? error.toString() : message;
    });
    ref.read(toyCleanupControllerProvider.notifier).markModelError();
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Short headline for the current step, shown in the slim top bar (replaces
/// the old tall status card — same information, a fraction of the height).
String _statusTitle(LiveDetectionState state) {
  final collected = state.collectedToyCount;
  return switch (state.missionStatus) {
    CleanupMissionStatus.idle => 'Listo para empezar',
    CleanupMissionStatus.scanning => 'Buscando juguetes…',
    CleanupMissionStatus.rescanning => 'Buscando otro…',
    CleanupMissionStatus.cleanAreaVerification => 'Revisando el área…',
    CleanupMissionStatus.active ||
    CleanupMissionStatus.targetLost =>
      'Juguete ${collected + 1}',
    CleanupMissionStatus.confirmingPickup => '¿Lo recogiste?',
    CleanupMissionStatus.askingIfMoreToys => '¿Ves otro juguete?',
    CleanupMissionStatus.waitingForChildTap => 'No lo veo bien',
    CleanupMissionStatus.completed => '¡Terminaste!',
    CleanupMissionStatus.cancelled => 'Misión cancelada',
    CleanupMissionStatus.error => 'No se pudo iniciar',
  };
}

/// One slim row above the camera: back button · current step · collected
/// count. Deliberately short so the camera below owns the screen.
class _MissionTopBar extends StatelessWidget {
  const _MissionTopBar({
    required this.title,
    required this.collected,
    required this.goal,
    required this.personalBest,
    required this.hasReachedGoal,
    required this.isNewRecord,
    required this.onBack,
  });

  final String title;
  final int collected;
  final int? goal;
  final int personalBest;
  final bool hasReachedGoal;
  final bool isNewRecord;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.missionTitle.copyWith(fontSize: 20),
              ),
            ),
          ),
        ),
        _ScorePanel(
          collected: collected,
          goal: goal,
          personalBest: personalBest,
          hasReachedGoal: hasReachedGoal,
          isNewRecord: isNewRecord,
        ),
      ],
    );
  }
}

/// "🧺 N / meta" — the challenge score. Shows progress toward the GOAL (a
/// challenge target, never "toys left in the room"), the personal record to
/// beat, and celebrates reaching the goal / setting a new record. In free
/// (record) mode there is no "/ meta" — every pickup is a record attempt.
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.collected,
    required this.goal,
    required this.personalBest,
    required this.hasReachedGoal,
    required this.isNewRecord,
  });

  final int collected;
  final int? goal;
  final int personalBest;
  final bool hasReachedGoal;
  final bool isNewRecord;

  @override
  Widget build(BuildContext context) {
    final reached = hasReachedGoal || isNewRecord;
    final basketLabel = goal == null ? '$collected' : '$collected / $goal';
    final subLabel = isNewRecord
        ? '¡Nuevo récord!'
        : (personalBest > 0 ? 'Récord: $personalBest' : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: reached ? AppColors.missionYellow : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPlayfulIcon(
                symbol: AppPlayfulIconSymbol.toyBasket,
                size: 22,
                color: reached ? Colors.white : AppColors.primaryBlue,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                basketLabel,
                style: AppTypography.missionTitle.copyWith(
                  fontSize: 18,
                  color: reached ? Colors.white : AppColors.textBlueDark,
                ),
              ),
            ],
          ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: AppTypography.missionTitle.copyWith(
              fontSize: 11,
              color: isNewRecord ? AppColors.missionYellow : Colors.white,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, color: AppColors.textBlueDark, size: 24),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Camera card
// ---------------------------------------------------------------------------

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.config,
    required this.controller,
    required this.cameraEpoch,
    required this.state,
    required this.errorMessage,
    required this.onResult,
    required this.onModelLoad,
    required this.onModelError,
    required this.onRetry,
    required this.onChildTap,
    required this.onToggleDiagnostics,
  });

  final YoloModelConfig config;
  final YOLOViewController controller;

  /// Resume epoch — part of the [YOLOView] key so the native camera surface is
  /// recreated when the app returns from the background (fixes the black feed).
  final int cameraEpoch;
  final LiveDetectionState state;
  final String? errorMessage;
  final void Function(List<YOLOResult>) onResult;
  final Future<void> Function(String, YOLOTask?) onModelLoad;
  final void Function(Object, String, YOLOTask?) onModelError;
  final VoidCallback onRetry;
  final VoidCallback onToggleDiagnostics;

  /// Called with normalized (0..1) tap coordinates when the child taps a toy
  /// the model missed (fallback / help only).
  final void Function(double nx, double ny) onChildTap;

  @override
  Widget build(BuildContext context) {
    // Manual tap is a LAST-RESORT debug/accessibility affordance only — in
    // the kid-facing (release) build there is no tap-to-add; the child uses
    // "Buscar otra vez" instead. The automatic detector is the only path.
    final tapToAdd = kDebugMode &&
        state.missionStatus == CleanupMissionStatus.waitingForChildTap;
    // The camera stays LIVE while scanning AND while guiding (active /
    // targetLost) so the "Recoge este" highlight tracks the toy in real time.
    // We only dim during the paused decision states, where the child is
    // answering a question rather than aiming at a toy.
    const frozenStates = {
      CleanupMissionStatus.confirmingPickup,
      CleanupMissionStatus.askingIfMoreToys,
      CleanupMissionStatus.waitingForChildTap,
    };
    final frozenGuidance = state.status == ModelStatus.ready &&
        frozenStates.contains(state.missionStatus);

    // Hero treatment: just a thin white frame + soft shadow around an almost
    // edge-to-edge preview, so the live camera reads as the main surface
    // (not a small element framed inside a big white card).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.cardWhite, width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl - 4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            YOLOView(
              // Changing the key on resume disposes the dead native camera
              // surface and creates a fresh, live one.
              key: ValueKey('yoloview-$cameraEpoch'),
              modelPath: config.modelPath,
              task: config.task,
              controller: controller,
              cameraResolution: config.cameraResolution,
              confidenceThreshold: config.confidenceThreshold,
              iouThreshold: config.iouThreshold,
              useGpu: config.useGpu,
              lensFacing: LensFacing.back,
              onModelLoad: onModelLoad,
              onModelError: onModelError,
              onResult: onResult,
            ),
            // Freeze the live camera while guiding: dim it so the scene
            // reads as a paused snapshot and the frozen boxes pop. The
            // camera is only "live" during scanning/rescanning.
            if (frozenGuidance)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x73000000)),
                ),
              ),
            if (state.status == ModelStatus.ready &&
                state.missionStatus != CleanupMissionStatus.completed)
              // Positioned.fill so the painter's canvas is exactly the camera
              // card — normalized boxes then land on the right spot (a bare
              // CustomPaint in a Stack can collapse to zero size).
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: DetectionOverlayPainter(
                      toys: state.visibleToys,
                      targetToyId: state.currentTargetToyId,
                    ),
                  ),
                ),
              ),
            // Fallback: tap a toy the model missed.
            if (tapToAdd)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      final nx = (d.localPosition.dx / constraints.maxWidth)
                          .clamp(0.0, 1.0);
                      final ny = (d.localPosition.dy / constraints.maxHeight)
                          .clamp(0.0, 1.0);
                      if (kDebugMode) {
                        debugPrint('OverlayDX: tapPositionScreen='
                            '(${d.localPosition.dx.toStringAsFixed(0)},'
                            '${d.localPosition.dy.toStringAsFixed(0)}) '
                            'previewRect=${constraints.maxWidth.toStringAsFixed(0)}x'
                            '${constraints.maxHeight.toStringAsFixed(0)} '
                            'normalizedTapPoint='
                            '(${nx.toStringAsFixed(3)},${ny.toStringAsFixed(3)})');
                      }
                      onChildTap(nx, ny);
                    },
                  ),
                ),
              ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: GestureDetector(
                onLongPress: onToggleDiagnostics,
                child: const _ScanBadge(),
              ),
            ),
            // Coach moved OUT of the camera (now a strip above it) so nothing
            // covers the preview.
            if (state.status == ModelStatus.initializing)
              const _LoadingOverlay(),
            if (state.status == ModelStatus.error)
              _ErrorOverlay(
                message: errorMessage ?? 'Error desconocido.',
                onRetry: onRetry,
              ),
            if (state.missionStatus == CleanupMissionStatus.completed)
              _CompletedOverlay(state: state),
          ],
        ),
      ),
    );
  }
}

class _ScanBadge extends StatelessWidget {
  const _ScanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.card,
      ),
      child: const AppPlayfulIcon(
        symbol: AppPlayfulIconSymbol.cameraScan,
        size: 24,
        color: AppColors.primaryBlue,
      ),
    );
  }
}

/// Small robot + short message shown ABOVE the camera (never over it).
class _CoachStrip extends StatelessWidget {
  const _CoachStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AppImage(
          assetPath: AppAssets.robotMascot,
          fallbackIcon: Icons.smart_toy_rounded,
          size: 40,
          fallbackColor: AppColors.primaryBlue,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.card,
            ),
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.coachMessage.copyWith(
                color: AppColors.textBlueDark,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: AppSpacing.md),
          Text(
            'Preparando la misión…',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.stopRed,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No se pudo iniciar el detector.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _CompletedOverlay extends StatelessWidget {
  const _CompletedOverlay({required this.state});

  final LiveDetectionState state;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => MissionCompletePanel(
        collectedToyCount: state.collectedToyCount,
        onNewMission:
            ref.read(toyCleanupControllerProvider.notifier).resetMission,
        onSeeStars: () =>
            ref.read(appTabProvider.notifier).state = AppTab.progress,
      ),
    );
  }
}

class _MissionDiagnosticsPanel extends StatelessWidget {
  const _MissionDiagnosticsPanel({required this.snapshot});

  final MissionDebugSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null) return const SizedBox.shrink();
    String score(double? value) =>
        value == null ? '-' : value.toStringAsFixed(2);
    String fps(double? value) => value == null ? '-' : value.toStringAsFixed(1);
    String confidence(double? value) =>
        value == null ? '-' : value.toStringAsFixed(2);
    String reasons(Map<String, int> value) {
      if (value.isEmpty) return '-';
      return value.entries.map((e) => '${e.key}:${e.value}').join(', ');
    }

    final rows = s.rawDetections.take(5).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detection Lab'),
              Text('modelLoaded=${s.modelLoaded} custom=${s.isCustomToyModel} '
                  'task=${s.modelTask ?? '-'}'),
              Text('configured=${s.configuredModelPath}'),
              Text('loaded=${s.loadedModelPath ?? '-'}'),
              Text('threshold=${s.modelConfidenceThreshold.toStringAsFixed(2)} '
                  'iou=${s.modelIouThreshold.toStringAsFixed(2)} '
                  'res=${s.cameraResolution}'),
              Text('labels=${s.loadedLabelCount} '
                  '[${s.loadedLabelsPreview.join(', ')}]'),
              Text('flow=${s.flowState.name} target=${s.activeTargetId ?? '-'} '
                  'visible=${s.visibleToyCount} baseline=${s.baselineToyCount ?? '-'} '
                  'remaining=${s.remainingToyCount}'),
              // Detection funnel — read left to right; the first column that
              // drops to 0 is where recall dies.
              Text('FUNNEL raw=${s.rawDetectionsCount} '
                  '→ mapped=${s.mappedDetectionsCount} '
                  '→ valid=${s.validToyCount} '
                  '→ visible=${s.visibleToyCount} '
                  '→ green=${s.greenOverlayCount}'),
              Text(
                'VERDICT ${s.recallVerdict}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('unknown=${s.unknownToyCount} '
                  'rejected=${s.rejectedDetectionsCount}'),
              Text('rejectReasons=${reasons(s.rejectionReasons)}'),
              for (final row in rows)
                Text('${row.rawLabel}:${confidence(row.confidence)} '
                    '-> ${row.mappedLabel ?? '-'} '
                    'id=${row.identityType ?? '-'} '
                    'toy=${row.countsAsToy} '
                    'reject=${row.rejectReason ?? '-'}'),
              Text(
                  'fps=${fps(s.approxFps)} frameMs=${s.frameIntervalMs ?? '-'} '
                  'targetConf=${confidence(s.targetConfidence)} '
                  'miss=${s.targetMissingFrameCount}'),
              Text('scene=${s.sceneStabilityStatus?.name ?? '-'} '
                  'reason=${s.sceneStabilityReason?.name ?? '-'} '
                  'score=${score(s.sceneStabilityScore)}'),
              Text('guard=${s.guardDecision} reason=${s.guardReason} '
                  'completedAllowed=${s.completedAllowed}'),
              const _ThresholdStepper(),
            ],
          ),
        ),
      ),
    );
  }
}

/// DEBUG-ONLY confidence-threshold A/B control for the Detection Recall Lab.
/// Taps set [debugDetectionConfidenceProvider]; "auto" clears it back to the
/// model's resolved threshold. Each change rebuilds YOLOView so the new floor
/// applies to the next scan. Lets recall be calibrated with evidence instead
/// of guessing — without editing production defaults.
class _ThresholdStepper extends ConsumerWidget {
  const _ThresholdStepper();

  static const List<double> _options = [0.15, 0.20, 0.25, 0.30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(debugDetectionConfidenceProvider);
    Widget chip(String label, double? value) {
      final selected = current == value;
      return GestureDetector(
        onTap: () =>
            ref.read(debugDetectionConfidenceProvider.notifier).state = value,
        child: Container(
          margin: const EdgeInsets.only(right: 6, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.missionYellow : Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        const Text('confThr: '),
        chip('auto', null),
        for (final v in _options) chip(v.toStringAsFixed(2), v),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action row (varies by state)
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.controller,
    required this.audio,
  });

  final LiveDetectionState state;
  final ToyCleanupController controller;
  final AppAudioService audio;

  /// Wrap an action with a friendly sound: a happy chime for positive
  /// confirms, a soft pop otherwise. Audio never blocks the action.
  VoidCallback _sfx(VoidCallback action, {bool success = false}) => () {
        if (success) {
          audio.playButtonSuccess();
        } else {
          audio.playButtonTap();
        }
        action();
      };

  @override
  Widget build(BuildContext context) {
    switch (state.missionStatus) {
      case CleanupMissionStatus.idle:
        return PrimaryActionButton(
          label: 'Nueva misión',
          color: AppColors.primaryBlue,
          fontSize: 18,
          leading: _circledIcon(Icons.play_arrow_rounded),
          onPressed: _sfx(controller.startMission),
        );

      case CleanupMissionStatus.scanning:
      case CleanupMissionStatus.rescanning:
      case CleanupMissionStatus.cleanAreaVerification:
        return const _ScanningIndicator();

      case CleanupMissionStatus.active:
      case CleanupMissionStatus.targetLost:
        // FULLY AUTOMATIC: the robot detects the pickup and counts it by
        // itself. There is no manual "I picked it up" / "I need help" button —
        // the child just grabs the marked toy and the basket rises on its own.
        return const _AutoPickupHint();

      case CleanupMissionStatus.confirmingPickup:
        // Rare manual fallback when the robot can't decide if the toy was
        // picked up. Two big, simple choices.
        return Row(
          children: [
            Expanded(
              child: PrimaryActionButton(
                label: 'Sí, lo recogí',
                color: AppColors.progressGreen,
                fontSize: 16,
                onPressed: _sfx(controller.confirmPickupYes),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryActionButton(
                label: 'Todavía no',
                color: AppColors.primaryBlue,
                fontSize: 16,
                onPressed: _sfx(controller.confirmPickupNo),
              ),
            ),
          ],
        );

      case CleanupMissionStatus.askingIfMoreToys:
        // FULLY AUTOMATIC: no "¿Ves otro? / Terminé" buttons. The robot keeps
        // searching for the next toy on its own and finishes by itself once the
        // area has been clean long enough. (This state is no longer entered by
        // the automatic flow; the indicator is a safe fallback.)
        return const _ScanningIndicator();

      case CleanupMissionStatus.waitingForChildTap:
        // Automatic-first: the primary action re-scans with YOLO. Tapping a
        // toy still works silently on the camera as a last resort.
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: PrimaryActionButton(
                label: 'Buscar otra vez',
                color: AppColors.primaryBlue,
                fontSize: 16,
                onPressed: _sfx(controller.restartScan),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryActionButton(
                label: 'Terminé',
                color: AppColors.progressGreen,
                fontSize: 16,
                onPressed: _sfx(controller.childDone, success: true),
              ),
            ),
          ],
        );

      case CleanupMissionStatus.completed:
        // No bottom CTA when completed: MissionCompletePanel (the celebration
        // overlay) provides "Nueva misión" + "Ver mis estrellas". The caller
        // already skips building this row in the completed state; returning an
        // empty box keeps the switch exhaustive and guards against a duplicate
        // button if that guard is ever removed.
        return const SizedBox.shrink();

      case CleanupMissionStatus.cancelled:
        return PrimaryActionButton(
          label: 'Nueva misión',
          color: AppColors.primaryBlue,
          fontSize: 18,
          leading: _circledIcon(Icons.play_arrow_rounded),
          onPressed: _sfx(controller.startMission),
        );

      case CleanupMissionStatus.error:
        return PrimaryActionButton(
          label: 'Reintentar',
          color: AppColors.gamePurple,
          fontSize: 18,
          leading: _circledIcon(Icons.refresh_rounded),
          onPressed: _sfx(controller.resetMission),
        );
    }
  }
}

/// The bottom strip during the active mission: a calm, non-interactive hint
/// that the robot counts pickups by itself. Replaces the old "Ya lo guardé" /
/// "Necesito ayuda" buttons — the active mission is now fully automatic.
class _AutoPickupHint extends StatelessWidget {
  const _AutoPickupHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardWhite.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.card,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPlayfulIcon(
            symbol: AppPlayfulIconSymbol.toyBasket,
            size: 22,
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Recoge el juguete marcado. ¡Yo lo cuento solo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textBlueDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small translucent-white circle that wraps the leading icon on every
/// mission action pill — keeps the icons visually consistent across states.
Widget _circledIcon(IconData icon) {
  return Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0x33FFFFFF),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: Colors.white, size: 20),
  );
}

/// Non-tappable "Buscando…" pill shown while the robot scans.
class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SearchingDots(),
          SizedBox(width: AppSpacing.md),
          Text(
            'Buscando…',
            style: TextStyle(
              color: AppColors.textBlueDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

final missionDiagnosticsEnabledProvider = StateProvider<bool>((ref) => false);

/// DEBUG-ONLY native YOLO confidence-threshold override for the Detection
/// Recall Lab. `null` = use the resolved model's own threshold (production
/// behavior, untouched). When set in debug, the camera card rebuilds YOLOView
/// with this floor so recall can be A/B-tested live (0.15/0.20/0.25/0.30)
/// WITHOUT editing production defaults. Never read outside `kDebugMode`.
final debugDetectionConfidenceProvider = StateProvider<double?>((ref) => null);
