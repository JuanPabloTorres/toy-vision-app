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
import '../../ui/theme/app_button_styles.dart';
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
    extends ConsumerState<ToyCleanupCameraScreen> {
  final YOLOViewController _yoloController = YOLOViewController();
  String? _errorMessage;

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
    _audio = ref.read(appAudioServiceProvider);
    // Entering the mission: start the fun playground loop. play() replaces the
    // Home theme on the shared player — a single op, no stop/play race.
    _audio.playMissionMusic();
  }

  @override
  void dispose() {
    _audio.stopMissionMusic();
    super.dispose();
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
    final config = ref.watch(resolvedYoloConfigProvider).valueOrNull ??
        YoloModelConfig.fallback;

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
                  known: state.knownToyCount,
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
    ref.read(toyCleanupControllerProvider.notifier).markModelReady();
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
    required this.known,
    required this.onBack,
  });

  final String title;
  final int collected;
  final int known;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.missionTitle.copyWith(fontSize: 20),
            ),
          ),
        ),
        _CountChip(collected: collected, known: known),
      ],
    );
  }
}

/// "🧺 N de M" — toys collected out of those discovered so far (just "🧺 N"
/// until the robot knows how many there are).
class _CountChip extends StatelessWidget {
  const _CountChip({required this.collected, required this.known});

  final int collected;
  final int known;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppPlayfulIcon(
            symbol: AppPlayfulIconSymbol.toyBasket,
            size: 22,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            known > 0 ? '$collected de $known' : '$collected',
            style: AppTypography.missionTitle.copyWith(
              fontSize: 18,
              color: AppColors.textBlueDark,
            ),
          ),
        ],
      ),
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
    required this.state,
    required this.errorMessage,
    required this.onResult,
    required this.onModelLoad,
    required this.onModelError,
    required this.onRetry,
    required this.onChildTap,
  });

  final YoloModelConfig config;
  final YOLOViewController controller;
  final LiveDetectionState state;
  final String? errorMessage;
  final void Function(List<YOLOResult>) onResult;
  final Future<void> Function(String, YOLOTask?) onModelLoad;
  final void Function(Object, String, YOLOTask?) onModelError;
  final VoidCallback onRetry;

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
            const Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _ScanBadge(),
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
        // Clear hierarchy: "Listo, ya lo guarde" is the big, full-width
        // primary; "No encuentro ese juguete" is a small secondary underneath.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryActionButton(
              label: 'Listo, ya lo guarde',
              color: AppColors.progressGreen,
              fontSize: 20,
              leading: _circledIcon(Icons.check_rounded),
              // Success chime is played by the screen when the collected count
              // rises, so manual and AUTOMATIC pickups celebrate identically.
              onPressed: _sfx(controller.collectCurrentToy),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: _sfx(controller.needHelp),
              icon: const Icon(Icons.touch_app_rounded, size: 18),
              label: const Text('No encuentro ese juguete'),
              style: AppButtonStyles.text(color: AppColors.textBlueDark),
            ),
          ],
        );

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
        // Two-up: no leading icons + smaller text so both fit without clipping.
        return Row(
          children: [
            Expanded(
              child: PrimaryActionButton(
                label: 'Sí, veo otro',
                color: AppColors.primaryBlue,
                fontSize: 16,
                onPressed: _sfx(controller.childSeesAnotherToy),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryActionButton(
                label: 'No, terminé',
                color: AppColors.progressGreen,
                fontSize: 16,
                onPressed: _sfx(controller.childDone, success: true),
              ),
            ),
          ],
        );

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
