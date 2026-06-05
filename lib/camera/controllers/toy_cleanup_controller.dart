import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../business/cleanup_guidance_service.dart';
import '../../business/live_detection_state.dart';
import '../../business/mission/cleanup_mission_status.dart';
import '../../business/mission/mission_completion_guard.dart';
import '../../business/mission/mission_goal.dart';
import '../../business/mission/mission_state_machine.dart';
import '../../business/mission/scene_stability_service.dart';
import '../../business/mission/mission_vision_snapshot.dart';
import '../../business/mission/toy_candidate_fusion_service.dart';
import '../../business/mission/toy_mission_item.dart';
import '../../business/toy_category_registry.dart';
import '../../business/toy_counting_service.dart';
import '../../business/toy_detection_rules.dart';
import '../../core/config/realtime_detection_config.dart';
import '../../detection/models/bounding_box.dart';
import '../../detection/models/raw_detection.dart';
import '../../detection/yolo/yolo_detection_mapper.dart';
import '../../detection/yolo/yolo_model_config.dart';
import '../../storage/active_mission_repository.dart';
import '../../storage/mission_history_repository.dart';
import '../../storage/mission_record.dart';
import '../../tracking/iou_calculator.dart';
import '../../tracking/toy_tracking_engine.dart';
import '../../tracking/tracked_toy.dart';

/// Owns the live cleanup pipeline and the **automatic, progressive** mission
/// state machine (Phase 7).
///
/// The robot scans by itself, guides one toy at a time from a living
/// known-toy list, and runs autonomously: it DEDUCES a pickup (auto-collect),
/// SWITCHES target when the child pans to another valid toy (the old one stays
/// pending), and after the last toy VERIFIES the area is clean before
/// auto-completing. There is no adult inspection or area-marking step.
///
/// The "Recoge este" highlight is drawn ONLY with current evidence (the target
/// seen this frame); otherwise it hides and the robot says it is searching.
/// Safeguards keep a low-recall blip from ending the mission: auto-collect
/// needs a steady scene with anchors, target-switch needs a stable NEW toy,
/// clean-area auto-complete needs the area to have actually been seen, and a
/// manual finish is blocked while any toy is visible or pending.
class ToyCleanupController extends Notifier<LiveDetectionState> {
  late final RealtimeDetectionConfig _config;
  late final ToyCategoryRegistry _registry;
  late final YoloDetectionMapper _mapper;
  late final ToyDetectionRules _rules;
  late final ToyTrackingEngine _tracker;
  late final ToyCountingService _counter;
  late final CleanupGuidanceService _guidance;
  late final ToyCandidateFusionService _fusion;
  late final SceneStabilityService _sceneStability;
  late final MissionCompletionGuard _completionGuard;
  late final MissionStateMachine _missionStateMachine;
  final IoUCalculator _iou = const IoUCalculator();

  /// Wall clock — injectable so tests can advance time deterministically
  /// (the scan window is time-based, see [clockProvider]).
  late final DateTime Function() _clock;

  // --- Living mission state ---
  final List<ToyMissionItem> _known = [];

  /// The challenge goal for THIS mission (a suggested pickup target, NOT a room
  /// inventory). Set on [startMission]; defaults to normal (5).
  MissionGoal _goal = MissionGoal.defaultGoal;

  /// Best pickup count from PREVIOUS missions, read from history at start. The
  /// "Récord" line and "¡Nuevo récord!" celebration compare against this.
  int _personalBest = 0;

  int? _currentTargetId;
  int _orderCounter = 0;
  int _nextChildTapId = -1;

  /// Consecutive frames the current target has gone undetected while guiding.
  /// Drives the `active` ⇄ `targetLost` flip. Reset whenever a new target is
  /// chosen or the target is re-acquired.
  int _targetMissedFrames = 0;

  /// Consecutive frames a valid toy has been visible while in
  /// `askingIfMoreToys`, used to auto-resume the hunt for the next toy without
  /// a "Sí, veo otro" tap (the challenge keeps going automatically).
  int _askResumeFrames = 0;

  /// Consecutive post-pickup search windows in which the area was seen CLEAN
  /// (no toys). The mission auto-completes once this reaches
  /// [_requiredCleanSweeps] — the system deciding the child is done, with no
  /// "¿Ves otro? / Terminé" buttons. Reset whenever a new toy is found.
  int _cleanAreaSweeps = 0;

  /// Live tracker id the "Recoge este" highlight is currently following. The
  /// mission's `toyId` is its stable identity; this is the *live* track to
  /// draw on, re-pointed each time the toy is re-acquired (the tracker may
  /// drop and re-issue an id when the toy leaves and re-enters the frame).
  int? _targetTrackId;

  /// Wall-clock instant the target was last actually seen. Used as the
  /// FPS-independent guard for auto-collect (don't deduce a pickup from a
  /// momentary loss).
  DateTime? _targetLastSeenAt;

  /// A target that was lost WITHOUT an immediate confident auto-collect (the
  /// camera moved, or a blank/covered view) and is now awaiting a clean-area
  /// confirmation. While this is set the mission CANNOT complete without first
  /// resolving it: a verification sweep that confirms a clean, stable, SEEN
  /// area proves the toy was truly picked up → it is counted (+1) before the
  /// mission completes; if the toy reappears it goes back to the active target.
  /// This closes the "completed without counting the toy" bug.
  int? _pendingVerificationTargetId;

  /// Track ids of the OTHER objects visible the last time the target was seen
  /// — the "scene anchors". If they persist while the target vanishes, the
  /// camera is steady and the toy was really removed (→ auto-collect). If they
  /// all disappear too, the camera panned away (→ keep searching, never
  /// auto-collect). With no anchors (a lone toy) a pickup can't be told from a
  /// pan, so that case falls back to a manual confirmation.
  Map<int, BoundingBox> _sceneAnchors = const {};

  // --- Scan-window bookkeeping ---
  int _frame = 0;
  int _scanFrames = 0; // diagnostic only (NOT the window clock)
  int _scanAttempts = 0;
  bool _rescanFromAsk = false;
  Set<int> _lastVisibleIds = const {};
  DateTime? _scanStartedAt; // wall-clock start of the current scan window
  int _rawTotal = 0; // accumulated over the current window (diagnostics)
  int _mappedTotal = 0;
  int _validTotal = 0;

  // --- Transient coach line (e.g. "Apunta la cámara al juguete") ---
  String? _pendingMessage;
  int _pendingMessageFrames = 0;

  // --- Mission record bookkeeping ---
  DateTime? _missionStartedAt;
  bool _recorded = false;
  bool _baselineRecorded = false;
  int? _baselineToyCount;
  MissionFlowState _missionFlowState = MissionFlowState.scanning;
  SceneStabilityResult? _lastSceneStability;

  /// Single source of truth for what the camera saw this frame. The overlay
  /// and the completion guard both read from it, so a painted green box and a
  /// "clean area" verdict can never disagree (FASE 3 unification).
  MissionVisionSnapshot _lastVisionSnapshot = MissionVisionSnapshot.empty;
  String _lastGuardDecision = 'notEvaluated';
  String _lastGuardReason = 'missionNotEvaluatedYet';
  bool _lastCompletedAllowed = false;
  DateTime? _lastFrameAt;
  Duration? _lastFrameInterval;
  double? _approxFps;
  int _lastRawDetectionsCount = 0;
  int _lastMappedDetectionsCount = 0;
  int _lastValidToyCount = 0;
  int _lastUnknownToyCount = 0;
  int _lastRejectedDetectionsCount = 0;
  Map<String, int> _lastRejectionReasons = const {};
  List<DetectionDiagnosticRow> _lastDetectionDiagnostics = const [];
  YoloModelConfig _activeYoloConfig = YoloModelConfig.fallback;
  bool _modelLoaded = false;
  String? _loadedModelPath;
  String? _loadedModelTask;

  // --- Verification metadata, accumulated over the run and persisted on the
  // mission record (surfaced in the Parents view). All start false = a clean,
  // fully-automatic, visually-unverified run. ---
  /// The mission ended through a PASSED clean-area verification sweep (the
  /// robot saw the area and confirmed nothing was left), not a bare finish.
  bool _visuallyVerified = false;

  /// The child needed a manual assist: tapped a missed toy, used "Necesito
  /// ayuda", or answered the "¿Lo recogiste?" fallback.
  bool _usedManualHelp = false;

  /// The run hit an uncertainty event: a lost-target re-scan (camera moved /
  /// blank view) or the manual pickup-confirmation fallback.
  bool _hadUncertainty = false;

  // --- Tunables ---
  // Scan windows are TIME-based (see RealtimeDetectionConfig.initialScan/
  // rescanDuration). The automatic flow tries hard for the full duration
  // (× retries) before ever asking the child to tap — tap is the last resort.
  static const int _maxScanAttempts = 3; // initial sweep + 3 retries, then tap
  static const int _minCandidateFrames = 2;
  static const int _pendingMessageDuration = 30;

  /// Consecutive clean search windows before the mission auto-completes ("the
  /// child is done"). At ~3s per window this is a few seconds of "no more toys"
  /// — patient enough not to end on a single clean frame, automatic enough to
  /// finish without a button. Tunable.
  static const int _requiredCleanSweeps = 2;

  @override
  LiveDetectionState build() {
    _config = ref.watch(realtimeConfigProvider);
    _registry = ref.watch(toyCategoryRegistryProvider);
    _mapper = const YoloDetectionMapper();
    _rules = ToyDetectionRules(_registry);
    _tracker = ToyTrackingEngine(config: _config);
    _counter = ToyCountingService(config: _config);
    _guidance = const CleanupGuidanceService();
    _fusion = ToyCandidateFusionService();
    _sceneStability = SceneStabilityService();
    _completionGuard = const MissionCompletionGuard();
    _missionStateMachine = const MissionStateMachine();
    _clock = ref.watch(clockProvider);
    return LiveDetectionState.initial();
  }

  /// Reset the timing + accumulators for a fresh scan/re-scan window.
  void _startScanWindow() {
    _fusion.reset();
    _scanFrames = 0;
    _scanStartedAt = _clock();
    _rawTotal = 0;
    _mappedTotal = 0;
    _validTotal = 0;
  }

  // ----------------------------------------------------------------
  // Per-frame entry point
  // ----------------------------------------------------------------

  void ingest(List<YOLOResult> yoloResults) {
    if (state.status == ModelStatus.error) return;
    _frame += 1;
    final frameAt = _clock();
    final previousFrameAt = _lastFrameAt;
    _lastFrameAt = frameAt;
    if (previousFrameAt != null) {
      _lastFrameInterval = frameAt.difference(previousFrameAt);
      final intervalMs = _lastFrameInterval!.inMicroseconds / 1000.0;
      _approxFps = intervalMs > 0 ? 1000.0 / intervalMs : null;
    }

    final mapped = _mapper.map(yoloResults);
    final validated = _rules.validate(mapped);
    _lastRawDetectionsCount = yoloResults.length;
    _lastMappedDetectionsCount = mapped.length;
    _lastValidToyCount = validated.length;
    _lastUnknownToyCount =
        validated.where((d) => d.label == 'unknownToy').length;
    _lastDetectionDiagnostics = _buildDetectionDiagnostics(yoloResults);
    _lastRejectedDetectionsCount =
        _lastDetectionDiagnostics.where((d) => d.rejectReason != null).length;
    _lastRejectionReasons = _rejectionHistogram(_lastDetectionDiagnostics);
    final tracked = _tracker.update(validated);
    final summary = _counter.update(tracked);
    final visibleIds = <int>{
      for (final t in tracked)
        if (t.isVisible) t.id,
    };
    _lastVisibleIds = visibleIds;

    // ONE per-frame vision snapshot — the single source of truth the overlay
    // and the completion guard both read, so "green box painted" and "area
    // clean" can never disagree (FASE 3).
    _lastVisionSnapshot = MissionVisionSnapshot(
      frameIndex: _frame,
      rawDetectionCount: yoloResults.length,
      mappedDetectionCount: mapped.length,
      visibleToyCount: visibleIds.length,
      greenOverlayCount: _greenOverlayCount(state.missionStatus, visibleIds),
      activeTargetId: _currentTargetId,
      pendingPickupTargetId: _pendingVerificationTargetId,
      sceneStability: _lastSceneStability?.status,
    );

    // --- YOLO diagnostic (debug only, throttled) ---
    // The single line that answers "is YOLO running, and what does it see?":
    //   raw  = how many objects YOLO returned this frame
    //   [..] = the actual class names YOLO emitted
    //   mapped = how many survived the toy mapper (COCO non-toy → dropped)
    //   valid  = how many passed confidence/box rules
    // If raw>0 but mapped==0, YOLO is alive but only sees non-toy COCO
    // classes — the recall ceiling that needs the custom toys.tflite.
    if (kDebugMode && _frame % 20 == 0) {
      final classes =
          yoloResults.map((r) => r.className).toSet().take(8).join(', ');
      debugPrint('YoloDX: status=${state.missionStatus.name} '
          'raw=${yoloResults.length} [$classes] '
          'mapped=${mapped.length} valid=${validated.length} '
          'visible=${visibleIds.length} known=${_known.length}');
    }
    if (kDebugMode &&
        (_frame <= 3 && yoloResults.isNotEmpty || _frame % 15 == 0)) {
      _logStructuredGateDiagnostics();
    }

    // LIVE GUIDANCE: outside the scan phases we do NOT run the scan-window
    // machinery, but while guiding one toy we keep its highlight glued to the
    // toy in the camera — re-associating the target with the live tracker
    // every frame, smoothing the box, and flipping to `targetLost`
    // ("Buscando el juguete…") after a grace window. Collection stays MANUAL:
    // a toy leaving the frame never auto-advances or completes the mission.
    final status = state.missionStatus;
    if (status != CleanupMissionStatus.scanning &&
        status != CleanupMissionStatus.rescanning &&
        status != CleanupMissionStatus.cleanAreaVerification) {
      if (status == CleanupMissionStatus.active ||
          status == CleanupMissionStatus.targetLost) {
        // rawCount = how many objects YOLO saw this frame (toy or not). A
        // non-empty scene means the camera is pointed at real context, not a
        // blank wall — a precondition for deducing a pickup.
        _updateLiveTarget(
          tracked,
          summary,
          rawClassNames: yoloResults.map((r) => r.className).toList(),
        );
      } else if (status == CleanupMissionStatus.askingIfMoreToys) {
        // Stay automatic BETWEEN toys: if the child points at another toy,
        // resume the hunt on our own instead of waiting for a "Sí, veo otro"
        // tap. A couple of stable frames guard against a one-frame blip. The
        // "No, terminé" button remains as the explicit escape.
        if (validated.isNotEmpty) {
          _askResumeFrames += 1;
          if (_askResumeFrames >= _minCandidateFrames) {
            _askResumeFrames = 0;
            _publish(_beginRescan(fromAsk: false));
          }
        } else {
          _askResumeFrames = 0;
        }
      }
      return;
    }

    _fusion.observe(tracked);
    _scanFrames += 1;
    _rawTotal += yoloResults.length;
    _mappedTotal += mapped.length;
    _validTotal += validated.length;

    final elapsed = _scanStartedAt == null
        ? Duration.zero
        : _clock().difference(_scanStartedAt!);

    if (kDebugMode && _scanFrames % 15 == 0) {
      // Where do detections die? mapperDropped = raw classes the toy mapper
      // refused (non-toy / unknown class). rulesReasons = of the mapped ones,
      // why they failed the confidence/box/category gates.
      final reasons = <String, int>{};
      _rules.validateWithReasons(mapped, reasons);
      final rawClasses =
          yoloResults.map((r) => r.className).toSet().take(8).join(', ');
      debugPrint(
          'MissionDX: scan f=$_scanFrames elapsedMs=${elapsed.inMilliseconds} '
          'raw=${yoloResults.length} [$rawClasses] '
          'mapped=${mapped.length} valid=${validated.length} '
          'mapperDropped=${yoloResults.length - mapped.length} '
          'rulesReasons=$reasons '
          'stable=${_fusion.stableCandidates(minFrames: _minCandidateFrames).length}');
    }

    // The scan window is measured by the WALL CLOCK, not by frame count, so
    // a fast device still scans long enough to gather several toys. We need
    // at least a couple of frames of data before resolving.
    final window = switch (status) {
      CleanupMissionStatus.scanning => _config.initialScanDuration,
      CleanupMissionStatus.cleanAreaVerification =>
        _config.cleanAreaVerificationDuration,
      _ => _config.rescanDuration,
    };
    var next = status;
    if (_scanFrames >= _minCandidateFrames && elapsed >= window) {
      next = switch (status) {
        CleanupMissionStatus.scanning => _finishScan(),
        CleanupMissionStatus.cleanAreaVerification =>
          _finishCleanAreaVerification(),
        _ => _finishRescan(),
      };
    }

    // While scanning, draw the LIVE detections so the child sees toys being
    // found. Once the scan finishes, the overlay is the FROZEN snapshot
    // (known boxes), which the UI draws over a dimmed/paused camera.
    final overlay = next.isScanningPhase
        ? [
            for (final t in tracked)
              // Draw toys being found, but NOT ones already collected — a
              // picked-up toy still in frame must not show a green box (nor
              // read as "a toy still to collect").
              if (t.isVisible && !_isCollectedTrack(t)) t,
          ]
        : null;
    _publish(next, summary: summary, overlay: overlay);
  }

  // ----------------------------------------------------------------
  // Scan resolution
  // ----------------------------------------------------------------

  CleanupMissionStatus _finishScan() {
    _logScanSummary('initial');
    _absorbCandidates(_collectScanCandidates());
    _advanceMissionFlow(MissionFlowEvent.scanCompleted);
    if (_selectNextTarget(_lastVisibleIds)) {
      _recordBaseline();
      _logTarget('scan found toys');
      return CleanupMissionStatus.active;
    }
    if (_scanAttempts < _maxScanAttempts) {
      _scanAttempts += 1;
      _startScanWindow();
      // Keep it automatic: encourage another sweep instead of bailing.
      _pendingMessage = 'No lo veo todavía. Mueve la cámara despacito.';
      _pendingMessageFrames = _pendingMessageDuration;
      return CleanupMissionStatus.scanning;
    }
    if (kDebugMode) {
      debugPrint('MissionDX: FALLBACK→waitingForChildTap '
          'reason=noCandidates attempts=$_scanAttempts known=${_known.length}');
    }
    return CleanupMissionStatus.waitingForChildTap;
  }

  /// Coach line inviting the child to find the next toy — phrased as a
  /// challenge ("te faltan N" until the goal), never as a room inventory.
  String _findNextToyMessage() {
    final goal = _goal.targetPickupGoal;
    final collected = _collectedCount();
    if (goal != null && collected < goal) {
      final left = goal - collected;
      final falta = left == 1 ? 'Te falta 1' : 'Te faltan $left';
      return '¡Bien! $falta. Busca otro juguete.';
    }
    return '¡Bien! Busca otro juguete.';
  }

  /// Reached at the end of a search window when there is NO pending
  /// (uncollected) toy to guide to. The mission stays FULLY automatic — no
  /// "¿Ves otro?" buttons — and the SYSTEM decides the child is done: it
  /// auto-completes once no more toys have been found for a few consecutive
  /// windows. Crucially this looks ONLY at "is there another toy to collect?",
  /// NOT at the raw camera view: a toy the child already collected but is still
  /// holding in frame, or a featureless (raw=0) floor, must NOT keep the
  /// mission alive — that is the "reached 3/3 but never finishes" bug. Once the
  /// challenge goal is met the mission finishes promptly (one empty window);
  /// while still chasing the goal it waits [_requiredCleanSweeps] windows so it
  /// never ends on a single momentary empty view ("finished at 1/3").
  CleanupMissionStatus _keepSearchingOrComplete() {
    // Record the guard's "is the visible area clean?" verdict for diagnostics
    // only — it no longer gates completion (a toy the child already collected
    // but is still holding in frame must NOT keep the mission alive; that was
    // the "reached 3/3 but never finishes" bug).
    final evidence = _completionEvidence();
    _recordCompletionGuardDecision(
      _completionGuard.canCompleteMission(evidence),
      evidence,
    );
    // We only get here when there is no PENDING (uncollected) toy to guide to.
    // Require that the camera actually SAW the area this window (raw>0): a
    // blank/covered view is ambiguous and must never auto-complete — it just
    // keeps looking. Collected toys still in frame DO satisfy "saw the area".
    if (_rawTotal <= 0) {
      _pendingMessage = 'Mueve la cámara para buscar más juguetes.';
      _pendingMessageFrames = _pendingMessageDuration;
      if (kDebugMode) {
        debugPrint('[Mission] Blank/covered view → keep searching');
      }
      _startScanWindow();
      return CleanupMissionStatus.cleanAreaVerification;
    }
    _cleanAreaSweeps += 1;
    // Once the challenge goal is met, finish promptly (one empty window); while
    // still chasing the goal, wait a couple of windows so a single momentary
    // empty view never ends the mission early ("finished at 1/3").
    final goalReached = _goal.hasReachedGoalAt(_collectedCount());
    final needed = goalReached ? 1 : _requiredCleanSweeps;
    if (_cleanAreaSweeps >= needed) {
      _confirmPendingCollection();
      _advanceMissionFlow(
        MissionFlowEvent.missionCompleted,
        guardApproved: true,
      );
      _visuallyVerified = true;
      if (kDebugMode) {
        debugPrint('[Mission] No more toys for $_cleanAreaSweeps/$needed sweeps '
            '(goalReached=$goalReached) → auto-complete '
            'collected=${_collectedCount()}');
      }
      return _completeMission();
    }
    // Saw the area, no toy to collect, but not long enough yet → keep hunting.
    _confirmPendingCollection();
    _pendingMessage = _findNextToyMessage();
    _pendingMessageFrames = _pendingMessageDuration;
    if (kDebugMode) {
      debugPrint('[Mission] No pending toy, area seen ($_cleanAreaSweeps/$needed)'
          ' → keep searching');
    }
    _startScanWindow();
    return CleanupMissionStatus.cleanAreaVerification;
  }

  CleanupMissionStatus _finishRescan() {
    _logScanSummary('rescan');
    _absorbCandidates(_collectScanCandidates());
    if (_selectNextTarget(_lastVisibleIds, requireVisible: true)) {
      // A toy is visible again — the active flow takes over. The previously
      // lost target is superseded; it will be re-counted if/when it is itself
      // picked up and verified.
      _pendingVerificationTargetId = null;
      _advanceMissionFlow(MissionFlowEvent.visibleToysRemaining);
      _logTarget('rescan found more toys');
      return CleanupMissionStatus.active;
    }
    // A re-scan triggered by the child tapping (fromAsk) keeps the tap
    // fallback. Otherwise stay fully automatic: keep sweeping for the next toy
    // and let the system decide when the child is done.
    if (_rescanFromAsk) return CleanupMissionStatus.waitingForChildTap;
    return _keepSearchingOrComplete();
  }

  /// End of the post-collect "clean area" sweep. If a toy turned up, continue
  /// the mission with it; if the area was genuinely seen and nothing remains,
  /// the mission auto-completes (no "¿ves otro?" needed). Only if the camera
  /// saw NOTHING at all (a blank/covered view) do we fall back to asking — so
  /// a low-recall blip never ends the mission prematurely.
  CleanupMissionStatus _finishCleanAreaVerification() {
    _logScanSummary('cleanArea');
    _absorbCandidates(_collectScanCandidates());
    if (_selectNextTarget(_lastVisibleIds, requireVisible: true)) {
      _pendingVerificationTargetId = null;
      _advanceMissionFlow(MissionFlowEvent.visibleToysRemaining);
      if (kDebugMode) {
        debugPrint('[Mission] More toys found after collect: '
            'count=${_pendingCount()}');
      }
      _pendingMessage = 'Veo otro juguete. Vamos por el próximo.';
      _pendingMessageFrames = _pendingMessageDuration;
      return CleanupMissionStatus.active;
    }
    // No toy in view: keep searching automatically and let the system decide
    // when the area has been clean long enough to finish.
    return _keepSearchingOrComplete();
  }

  /// Start the short "is the floor clean?" sweep (also the path that finds the
  /// next toy after a pickup). Clears the target and resets the scan window.
  CleanupMissionStatus _beginCleanAreaVerification() {
    _currentTargetId = null;
    _targetTrackId = null;
    _targetMissedFrames = 0;
    _targetLastSeenAt = null;
    _sceneAnchors = const {};
    _sceneStability.reset();
    _advanceMissionFlow(MissionFlowEvent.noToysVisible);
    _rescanFromAsk = false;
    _startScanWindow();
    // Base the coach line on what is VISIBLE now, not on the baseline count:
    // if another toy is on screen we go for it; otherwise we verify the area.
    final verifying = _lastVisibleIds.isEmpty;
    if (kDebugMode) {
      debugPrint(
        verifying
            ? '[Mission] Clean area verification started'
            : '[Mission] Searching for the next toy',
      );
    }
    _pendingMessage =
        verifying ? 'Estoy revisando el área…' : 'Vamos por el próximo.';
    _pendingMessageFrames = _pendingMessageDuration;
    return CleanupMissionStatus.cleanAreaVerification;
  }

  /// Evidence for completing the mission, based ONLY on what the camera SEES
  /// now — never on the initial baseline. The camera sees only part of the
  /// room, so an over-counted baseline (grouped / hidden / off-frame toys)
  /// must NOT keep the mission alive. We complete when the sweep actually saw
  /// the area (rawTotal>0, not a blank/covered view), no toy is visible right
  /// now, and no valid toy was detected across the whole verification window.
  MissionCompletionEvidence _completionEvidence() {
    final sawArea = _rawTotal > 0; // real context, not a blank/covered view
    final visibleAreaClean = _lastVisibleIds.isEmpty && _validTotal == 0;
    final cleanAndStable = sawArea && visibleAreaClean && _scanFrames > 0;
    return MissionCompletionEvidence(
      // Baseline/pending is diagnostic only — NEVER a completion gate.
      pendingToyCount: 0,
      visibleToyCount: _lastVisibleIds.length,
      // From the same snapshot the overlay paints from: a green box this frame
      // structurally blocks completion (FASE 2 rule #1).
      greenOverlayDetectionCount: _lastVisionSnapshot.greenOverlayCount,
      validatedToyDetectionsInSweep: _validTotal,
      // A blank/covered view (rawTotal==0) is "not sure" → not stable → the
      // robot asks the child to point at the area again instead of completing.
      sceneStability: cleanAndStable
          ? SceneStabilityStatus.stable
          : SceneStabilityStatus.insufficientEvidence,
      sawOnlyRawNonToyDetections: false,
    );
  }

  /// Finalize a clean, finished mission: persist it (which feeds the calendar
  /// and the parents' stats) and flip to the celebration.
  CleanupMissionStatus _completeMission() {
    if (kDebugMode) {
      debugPrint('[Mission] Completed and saved '
          'collected=${_collectedCount()} known=${_known.length}');
    }
    _recordMission(completed: true);
    return CleanupMissionStatus.completed;
  }

  /// Structured log: a target was CONFIRMED collected (the only place the
  /// collected score is allowed to rise). Logged just before the +1 lands.
  void _logCollected(String reason) {
    if (!kDebugMode) return;
    final id = _currentTargetId ?? _pendingVerificationTargetId;
    final prev = _collectedCount();
    debugPrint('[COLLECTED] targetId=${id != null ? _fmtId(id) : "-"} '
        'previousCollected=$prev newCollected=${prev + 1} reason=$reason');
  }

  /// A verification sweep confirmed a clean, stable, SEEN area while a target
  /// was pending verification → that toy WAS picked up. Count it (+1) now, so
  /// the mission can never complete with an uncounted toy. No-op if nothing is
  /// pending (the toy was already counted via a confident auto-collect).
  void _confirmPendingCollection() {
    final id = _pendingVerificationTargetId;
    if (id == null) return;
    final item = _itemById(id);
    if (item != null && !item.isCollected) {
      _logCollected('pendingTargetVerifiedByCleanArea');
      item.status = ToyItemStatus.collected;
      item.collectedAtFrame = _frame;
    }
    _pendingVerificationTargetId = null;
  }

  void _logScanSummary(String kind) {
    if (!kDebugMode) return;
    final ms = _scanStartedAt == null
        ? 0
        : _clock().difference(_scanStartedAt!).inMilliseconds;
    debugPrint('MissionDX: $kind-scan DONE scanElapsedMs=$ms '
        'framesProcessed=$_scanFrames rawTotal=$_rawTotal '
        'mappedTotal=$_mappedTotal validTotal=$_validTotal '
        'stableCandidates=${_fusion.stableCandidates(minFrames: _minCandidateFrames).length}');
  }

  /// Candidates to commit at the end of a scan. Prefer the stable ones
  /// (seen on ≥ [_minCandidateFrames] frames). But if NONE reached that bar
  /// yet at least one toy was glimpsed, accept those single-frame sightings
  /// too — "if it detected even one toy, present it" beats failing to a tap.
  List<ToyCandidate> _collectScanCandidates() {
    final stable = _fusion.stableCandidates(minFrames: _minCandidateFrames);
    if (stable.isNotEmpty) return stable;
    return _fusion.stableCandidates(minFrames: 1);
  }

  /// Merge stable candidates into the living known-toy list, deduping
  /// against toys we already know (and never reviving a collected one).
  void _absorbCandidates(List<ToyCandidate> candidates) {
    var added = 0;
    var revived = 0;
    for (final c in candidates) {
      ToyMissionItem? match;
      for (final k in _known) {
        if (k.toyId == c.trackerId || _near(k.box, c.box)) {
          match = k;
          break;
        }
      }
      if (match != null) {
        if (match.status == ToyItemStatus.collected) continue;
        match.box = c.box;
        match.confidence = c.confidence;
        match.lastSeenFrame = _frame;
        if (match.status == ToyItemStatus.lost) {
          match.status = ToyItemStatus.pending;
          revived += 1;
        }
        continue;
      }
      _known.add(
        ToyMissionItem(
          toyId: c.trackerId,
          source: ToySource.automaticDetection,
          box: c.box,
          confidence: c.confidence,
          orderIndex: _orderCounter++,
          firstSeenFrame: _frame,
        ),
      );
      added += 1;
    }
    if (kDebugMode) {
      debugPrint('MissionDX: absorb new=$added revived=$revived '
          'known=${_known.length} pending=${_pendingCount()}');
    }
  }

  bool _near(BoundingBox a, BoundingBox b) {
    final dx = a.centerX - b.centerX;
    final dy = a.centerY - b.centerY;
    // ~0.16 normalized center distance — also acts as the "collected region"
    // guard so a re-detected toy isn't re-added as pending after pickup.
    return (dx * dx + dy * dy) < 0.025;
  }

  // ----------------------------------------------------------------
  // Target selection / maintenance
  // ----------------------------------------------------------------

  /// Pick the next pending toy as the current target. Prefers toys the
  /// camera can see right now, then visual order. Returns false when there
  /// is nothing pending.
  bool _selectNextTarget(Set<int> visibleIds, {bool requireVisible = false}) {
    var pending =
        _known.where((k) => k.status == ToyItemStatus.pending).toList();
    // After a pickup we only re-target toys the camera can SEE right now, so a
    // stale/over-counted baseline (grouped, hidden, or off-frame toys) never
    // makes the robot chase a "ghost" that isn't there — which would otherwise
    // either falsely auto-collect or loop forever instead of completing.
    if (requireVisible) {
      pending = pending.where((k) => visibleIds.contains(k.toyId)).toList();
    }
    if (pending.isEmpty) {
      _currentTargetId = null;
      return false;
    }
    pending.sort((a, b) {
      final av = visibleIds.contains(a.toyId) ? 0 : 1;
      final bv = visibleIds.contains(b.toyId) ? 0 : 1;
      if (av != bv) return av - bv;
      return a.orderIndex.compareTo(b.orderIndex);
    });
    for (final k in _known) {
      if (k.status == ToyItemStatus.currentTarget) {
        k.status = ToyItemStatus.pending;
      }
    }
    final chosen = pending.first;
    chosen.status = ToyItemStatus.currentTarget;
    _currentTargetId = chosen.toyId;
    _targetTrackId = chosen.toyId;
    _targetMissedFrames = 0;
    _cleanAreaSweeps = 0; // a new toy appeared → restart the "done" countdown
    // The toy was just seen during the scan; anchors fill in on the next live
    // match. Seeds the auto-collect "seconds since last seen" guard.
    _targetLastSeenAt = _clock();
    _sceneAnchors = const {};
    _sceneStability.reset();
    _advanceMissionFlow(MissionFlowEvent.targetSelected);
    if (kDebugMode) {
      final verb =
          _collectedCount() > 0 ? 'Next target selected' : 'Target selected';
      debugPrint('[Tracker] $verb: id=${_fmtId(chosen.toyId)}');
    }
    return true;
  }

  /// Live guidance step: glue the single "Recoge este" highlight onto the
  /// current target in this frame. Only the target is tracked/drawn while
  /// guiding — secondary toys are not shown, so the child sees one clear box
  /// on the toy to pick up. The target's miss counter flips the mission
  /// between `active` and `targetLost`; collection is never inferred from the
  /// frame (a toy leaving the view only dims/searches, never auto-collects).
  void _updateLiveTarget(
    List<TrackedToy> tracked,
    ToyCountSummary summary, {
    required List<String> rawClassNames,
  }) {
    final visible = [
      for (final t in tracked)
        if (t.isVisible) t,
    ];

    final target =
        _currentTargetId != null ? _itemById(_currentTargetId!) : null;
    if (target != null && !target.isCollected) {
      // 1. Follow the SAME live track we locked onto — that is the exact box
      //    the scan overlay (the green frame the child saw land on the toy)
      //    draws, so the highlight stays glued to the toy as the camera moves.
      var match =
          _targetTrackId != null ? _firstById(visible, _targetTrackId!) : null;
      // 2. Lost that track (tracker aged it out / re-issued its id). Re-acquire
      //    only the SAME toy, near where it was last seen — NEVER hijack a
      //    different toy the camera passes over (that made the selected toy
      //    feel like it jumped around). If its toy isn't here, we wait in
      //    `targetLost` ("buscando") until it comes back into view.
      match ??= _reacquireMatch(target.box, visible);
      if (match != null) {
        final wasLost = _targetMissedFrames > _config.targetLostFrames;
        _targetTrackId = match.id;
        _adoptDetection(target, match, _config.targetSmoothing);
        _targetMissedFrames = 0;
        // Snapshot the scene anchors (other objects visible right now) so a
        // later disappearance can tell "toy removed, scene steady" from
        // "camera panned away".
        _targetLastSeenAt = _clock();
        // The toy is back on screen → it is the ACTIVE target again, not a
        // pending-verification one. (Test #10: target reappears during
        // verification → cancel the pickup, do not count, return to active.)
        _pendingVerificationTargetId = null;
        _sceneAnchors = {
          for (final t in visible)
            if (t.id != match.id) t.id: t.box,
        };
        _sceneStability.reset();
        _advanceMissionFlow(MissionFlowEvent.targetSeen);
        if (kDebugMode) {
          if (wasLost) {
            debugPrint(
              '[Tracker] Target recovered: id=${_fmtId(target.toyId)}',
            );
            debugPrint(
              '[Mission] Auto-collect cancelled: target recovered '
              'id=${_fmtId(target.toyId)}',
            );
            debugPrint(
              '[Mission] Target overlay restored: id=${_fmtId(target.toyId)}',
            );
          } else if (_frame % 15 == 0) {
            debugPrint('[Mission] Target overlay visible: '
                'id=${_fmtId(target.toyId)}');
          }
        }
      } else if (target.source == ToySource.childTap) {
        // A child-tapped marker is deliberate (the model missed the toy and
        // the child pointed at it). Keep it shown and never age it out — it is
        // never auto-collected; only the child confirms it.
        _targetMissedFrames = 0;
      } else {
        final wasVisible = _targetMissedFrames <= _config.targetLostFrames;
        _targetMissedFrames += 1;
        if (_targetMissedFrames == _config.targetLostFrames + 1) {
          _advanceMissionFlow(MissionFlowEvent.targetLost);
        }
        if (kDebugMode) {
          if (wasVisible) {
            debugPrint('[Mission] Target overlay hidden: target not visible');
          }
          if (_targetMissedFrames == _config.targetLostFrames + 1) {
            debugPrint('[Tracker] Target temporarily lost, evaluating removal:'
                ' id=${_fmtId(target.toyId)} missedFrames=$_targetMissedFrames');
          }
        }

        // SWITCH FIRST: if the child panned to a DIFFERENT, new valid toy,
        // follow them — the old target stays pending (never collected). This
        // beats both freezing on the old toy and falsely auto-collecting it.
        if (_maybeSwitchTarget(visible)) {
          _publish(CleanupMissionStatus.active, summary: summary);
          return;
        }

        // AUTO-COLLECT: only when NO other toy is around (truly picked up).
        if (_canAutoCollect(target, visible, rawClassNames)) {
          _advanceMissionFlow(
            MissionFlowEvent.collectionVerified,
            guardApproved: true,
          );
          if (kDebugMode) {
            debugPrint('[Mission] Auto-collected target: '
                'id=${_fmtId(target.toyId)} reason=stable_area_target_absent');
          }
          _collectTarget(auto: true);
          return;
        }
        if (kDebugMode &&
            _targetMissedFrames >= _config.autoCollectMinMissedFrames) {
          debugPrint('[Mission] Auto-collect pending: '
              'id=${_fmtId(target.toyId)} missedFrames=$_targetMissedFrames');
        }
      }
    }

    // Lost too long without a confident auto-collect → decide what to do
    // (never freeze a box, never auto-complete the mission).
    if (target != null &&
        target.source != ToySource.childTap &&
        _targetMissedFrames > _config.targetRescanFrames) {
      _resolveLongLoss(visible, rawClassNames);
      return;
    }

    // While unseen but still evaluating, say so plainly so the child either
    // moves the camera back or simply lifts the toy away.
    if (_targetMissedFrames >= _config.autoCollectEvaluatingFrames) {
      _pendingMessage = 'Estoy verificando…';
      _pendingMessageFrames = 2; // re-armed each frame, so it persists
    }

    final lost = _targetMissedFrames > _config.targetLostFrames;
    _publish(
      lost ? CleanupMissionStatus.targetLost : CleanupMissionStatus.active,
      summary: summary,
    );
  }

  /// Whether the robot may DEDUCE the current target was picked up. All must
  /// hold: it is an auto-detected toy (not a child-tap marker); it has been
  /// unseen long enough by BOTH frames and wall-clock; the camera still sees
  /// real context (not a blank wall); nothing compatible sits where the toy
  /// was; and the scene anchors persist (camera steady, not a pan). With no
  /// anchors the pickup can't be told from a pan, so this returns false and
  /// the ambiguity is resolved by the manual fallback in [_resolveLongLoss].
  bool _canAutoCollect(
    ToyMissionItem target,
    List<TrackedToy> visible,
    List<String> rawClassNames,
  ) {
    if (target.source == ToySource.childTap) return false;
    final lastSeen = _targetLastSeenAt;
    if (lastSeen == null) return false;
    var targetStillVisibleNearby = false;
    for (final t in visible) {
      if (_near(target.box, t.box)) {
        targetStillVisibleNearby = true;
        break;
      }
    }
    final scene = _sceneStability.evaluateDetailed(
      anchorBoxes: _sceneAnchors,
      visibleToys: visible,
      rawClassNames: rawClassNames,
      targetMissing: true,
    );
    _lastSceneStability = scene;
    final sustainedLoss =
        _targetMissedFrames >= _config.autoCollectMinMissedFrames &&
            _clock().difference(lastSeen) >=
                _config.autoCollectMinSecondsSinceLastSeen;
    if (scene.status == SceneStabilityStatus.probablyMoved) {
      _advanceMissionFlow(MissionFlowEvent.sceneMoved);
    } else if (scene.status == SceneStabilityStatus.stable) {
      _advanceMissionFlow(
        MissionFlowEvent.sceneStable,
        sustainedLoss: sustainedLoss,
      );
    }

    final evidence = TargetCollectionEvidence(
      missedFrames: _targetMissedFrames,
      requiredMissedFrames: _config.autoCollectMinMissedFrames,
      timeSinceLastSeen: _clock().difference(lastSeen),
      requiredTimeSinceLastSeen: _config.autoCollectMinSecondsSinceLastSeen,
      sceneStability: scene.status,
      targetStillVisibleNearby: targetStillVisibleNearby,
      hasNewUncollectedVisible: _hasNewUncollectedVisible(visible),
      // No anchors = the lone-toy base case. Lets the guard confirm a pickup
      // that the (anchor-based) scene check can never call "stable".
      sceneHadAnchors: _sceneAnchors.isNotEmpty,
    );
    final allowed = _completionGuard.canAutoCollectTarget(evidence);
    _recordAutoCollectGuardDecision(allowed, evidence, scene);
    if (!allowed && sustainedLoss) {
      _advanceMissionFlow(MissionFlowEvent.collectionRejected);
    }
    return allowed;
  }

  /// True if a toy that was NOT an anchor (i.e. appeared after the target was
  /// last seen — a different area) is visible and not already collected. Its
  /// presence means "camera moved", which blocks auto-collect and triggers a
  /// target switch.
  /// Whether [t] is a toy the child has already collected (matched by stable
  /// id or proximity to a collected known toy). Such a toy may still be in
  /// frame (held / in a basket) but must never read as a toy still to collect.
  bool _isCollectedTrack(TrackedToy t) {
    for (final k in _known) {
      if ((k.toyId == t.id || _near(k.box, t.box)) && k.isCollected) return true;
    }
    return false;
  }

  bool _hasNewUncollectedVisible(List<TrackedToy> visible) {
    for (final t in visible) {
      if (t.id == _targetTrackId) continue;
      if (_sceneAnchors.containsKey(t.id)) continue; // was there with target
      var collected = false;
      for (final k in _known) {
        if ((k.toyId == t.id || _near(k.box, t.box)) && k.isCollected) {
          collected = true;
          break;
        }
      }
      if (!collected) return true;
    }
    return false;
  }

  /// If the active target has been lost a while and a DIFFERENT, stable, NEW
  /// (non-anchor) valid toy is on screen, switch to it — the old target stays
  /// pending (never collected). This is how the robot follows the child when
  /// they pan to another toy instead of getting stuck on the first one.
  bool _maybeSwitchTarget(List<TrackedToy> visible) {
    if (!_config.allowTargetSwitchWhenNewValidToyVisible) return false;
    final id = _currentTargetId;
    final target = id != null ? _itemById(id) : null;
    if (target == null || target.isCollected) return false;
    if (target.source == ToySource.childTap) return false;
    if (_targetMissedFrames < _config.minFramesBeforeTargetSwitch) return false;
    final lastSeen = _targetLastSeenAt;
    if (lastSeen == null) return false;
    if (_clock().difference(lastSeen) < _config.minSecondsBeforeTargetSwitch) {
      return false;
    }

    for (final t in visible) {
      if (t.id == _targetTrackId) continue;
      if (_sceneAnchors.containsKey(t.id)) continue; // not "new" → not a switch
      if (t.framesSeen < _minCandidateFrames) continue; // not a one-frame blip
      final item = _missionItemForTrack(t);
      if (item.isCollected || item.toyId == target.toyId) continue;
      // Switch: old target back to pending (kept), new toy becomes active.
      target.status = ToyItemStatus.pending;
      item.status = ToyItemStatus.currentTarget;
      _currentTargetId = item.toyId;
      _targetTrackId = t.id;
      _targetMissedFrames = 0;
      _targetLastSeenAt = _clock();
      _sceneAnchors = {
        for (final v in visible)
          if (v.id != t.id) v.id: v.box,
      };
      if (kDebugMode) {
        debugPrint('[Mission] Active target lost: id=${_fmtId(target.toyId)}');
        debugPrint('[Mission] Active target moved to pending: '
            'id=${_fmtId(target.toyId)}');
        debugPrint('[Mission] New visible target found while previous pending: '
            'id=${_fmtId(item.toyId)}');
        debugPrint('[Mission] Target switched: from=${_fmtId(target.toyId)} '
            'to=${_fmtId(item.toyId)}');
      }
      _pendingMessage = '¡Veo otro juguete! Recoge este.';
      _pendingMessageFrames = _pendingMessageDuration;
      return true;
    }
    return false;
  }

  /// The mission item for a live [track]: an existing known toy (matched by
  /// stable id or proximity — so a returning toy keeps its identity and is
  /// never duplicated), or a brand-new one absorbed on the spot.
  ToyMissionItem _missionItemForTrack(TrackedToy track) {
    for (final k in _known) {
      if (k.toyId == track.id || _near(k.box, track.box)) return k;
    }
    final item = ToyMissionItem(
      toyId: track.id,
      source: ToySource.automaticDetection,
      box: track.box,
      confidence: track.confidence,
      orderIndex: _orderCounter++,
      firstSeenFrame: _frame,
    );
    _known.add(item);
    return item;
  }

  /// The target has been gone past the re-scan deadline and eager auto-collect
  /// did not already fire (e.g. the toy kept flickering in and out, repeatedly
  /// nudging the miss counter). A toy absent this long is not in front of the
  /// camera anymore → confirm the pickup now instead of looping in a re-scan
  /// that strands the child. The "pan to a NEW toy" case was already handled by
  /// the target switch and the new-toy guard before we ever get here.
  void _resolveLongLoss(List<TrackedToy> visible, List<String> rawClassNames) {
    // Scene stability is computed for diagnostics only — it no longer gates the
    // pickup (a hand reaching in must never block counting).
    _lastSceneStability = _sceneStability.evaluateDetailed(
      anchorBoxes: _sceneAnchors,
      visibleToys: visible,
      rawClassNames: rawClassNames,
      targetMissing: true,
    );
    _pendingVerificationTargetId = null;
    _advanceMissionFlow(
      MissionFlowEvent.collectionVerified,
      guardApproved: true,
    );
    _logCollected('targetGoneBeyondDeadline');
    _collectTarget(auto: true);
  }

  /// The visible track whose id is [id], or null. The target keeps its
  /// tracker id across frames (the engine maintains identity), so this is the
  /// fast, exact way to find the live box for the toy we are guiding to.
  TrackedToy? _firstById(List<TrackedToy> visible, int id) {
    for (final t in visible) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Move [item] onto its live [detection] and mark it seen. [factor] is the
  /// lerp amount: 1 snaps straight onto the detection (the box sits exactly
  /// where the detector sees the toy), smaller values glide to damp jitter
  /// (see [RealtimeDetectionConfig.targetSmoothing]).
  void _adoptDetection(
    ToyMissionItem item,
    TrackedToy detection,
    double factor,
  ) {
    item.box = BoundingBox.lerp(item.box, detection.box, factor);
    item.confidence = detection.confidence;
    item.lastSeenFrame = _frame;
  }

  /// The visible toy to re-lock the highlight onto after the tracker dropped
  /// its id — restricted to the SAME toy, near where it was last seen. Scores
  /// overlap most (the same IoU the tracker uses) plus a proximity term, and
  /// requires the accept floor, so it re-associates a toy nudged by a small
  /// pan but NEVER jumps to a different toy the camera passed over. If nothing
  /// clears the floor the highlight persists in place ("buscando") instead.
  TrackedToy? _reacquireMatch(BoundingBox reference, List<TrackedToy> visible) {
    TrackedToy? best;
    var bestScore = 0.0;
    for (final t in visible) {
      final overlap = _iou.iou(reference, t.box);
      final dx = reference.centerX - t.box.centerX;
      final dy = reference.centerY - t.box.centerY;
      final distance = math.sqrt(dx * dx + dy * dy);
      final proximity =
          (1 - distance / _config.targetMatchMaxCenterDistance).clamp(0.0, 1.0);
      final score = overlap * 0.7 + proximity * 0.3;
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return bestScore < _config.targetMatchMinScore ? null : best;
  }

  List<DetectionDiagnosticRow> _buildDetectionDiagnostics(
    List<YOLOResult> yoloResults,
  ) {
    return [
      for (final result in yoloResults) _diagnosticRowFor(result),
    ];
  }

  DetectionDiagnosticRow _diagnosticRowFor(YOLOResult result) {
    final mappedLabel = _mapper.mapLabelForDiagnostics(result.className);
    if (mappedLabel == null) {
      return DetectionDiagnosticRow(
        rawLabel: result.className,
        confidence: result.confidence,
        mappedLabel: null,
        identityType: null,
        countsAsToy: false,
        rejectReason: 'mapperDropped',
      );
    }

    final rawDetection = RawDetection(
      label: mappedLabel,
      confidence: result.confidence,
      box: BoundingBox(
        x: result.normalizedBox.left,
        y: result.normalizedBox.top,
        width: result.normalizedBox.width,
        height: result.normalizedBox.height,
      ),
    );
    final definition = _registry.lookup(mappedLabel);
    return DetectionDiagnosticRow(
      rawLabel: result.className,
      confidence: result.confidence,
      mappedLabel: mappedLabel,
      identityType: definition.identity.name,
      countsAsToy: definition.countsAsToy,
      rejectReason: _rules.rejectReason(rawDetection),
    );
  }

  Map<String, int> _rejectionHistogram(
    List<DetectionDiagnosticRow> diagnostics,
  ) {
    final reasons = <String, int>{};
    for (final row in diagnostics) {
      final reason = row.rejectReason;
      if (reason == null) continue;
      reasons.update(reason, (count) => count + 1, ifAbsent: () => 1);
    }
    return reasons;
  }

  void _logStructuredGateDiagnostics() {
    final rawLabels = _lastDetectionDiagnostics
        .map((d) => '${d.rawLabel}:${d.confidence.toStringAsFixed(2)}')
        .take(8)
        .join(', ');
    final rejected = _lastDetectionDiagnostics
        .where((d) => d.rejectReason != null)
        .map((d) => '${d.rawLabel}:${d.rejectReason}')
        .take(8)
        .join(', ');
    debugPrint('[RAW] count=$_lastRawDetectionsCount labels=[$rawLabels] '
        'model=${_activeYoloConfig.modelPath} '
        'loaded=${_loadedModelPath ?? '-'} '
        'custom=${_activeYoloConfig.isCustomToyModel}');
    debugPrint('[MAP] accepted=$_lastValidToyCount '
        'mapped=$_lastMappedDetectionsCount '
        'rejected=$_lastRejectedDetectionsCount reasons=[$rejected]');
    debugPrint('[MISSION] state=${_missionFlowState.name} '
        'baseline=${_baselineToyCount ?? '-'} visible=${_lastVisibleIds.length} '
        'remaining=${_remainingCount()} target=${_currentTargetId ?? '-'}');
    debugPrint('[SCENE] result=${_lastSceneStability?.status.name ?? '-'} '
        'score=${_lastSceneStability?.score.toStringAsFixed(2) ?? '-'} '
        'reason=${_lastSceneStability?.reason.name ?? '-'}');
    debugPrint('[GUARD] decision=$_lastGuardDecision '
        'reason=$_lastGuardReason completedAllowed=$_lastCompletedAllowed');
  }

  CleanupMissionStatus _beginRescan({required bool fromAsk}) {
    _advanceMissionFlow(MissionFlowEvent.rescanRequested);
    _rescanFromAsk = fromAsk;
    _currentTargetId = null;
    _targetTrackId = null;
    _targetMissedFrames = 0;
    _targetLastSeenAt = null;
    _sceneAnchors = const {};
    _sceneStability.reset();
    _startScanWindow();
    return CleanupMissionStatus.rescanning;
  }

  // ----------------------------------------------------------------
  // YOLO lifecycle callbacks
  // ----------------------------------------------------------------

  void recordModelLoaded(
    YoloModelConfig config, {
    required String loadedModelPath,
    required YOLOTask? task,
  }) {
    _activeYoloConfig = config;
    _modelLoaded = true;
    _loadedModelPath = loadedModelPath;
    _loadedModelTask = task?.name;
    if (kDebugMode) {
      // The single line that answers "which detector is actually live, and is
      // it the custom toy model or the COCO fallback?" — the first thing to
      // check in a recall investigation.
      final usingFallback = !config.isCustomToyModel;
      debugPrint('[MODEL]\n'
          '  path=$loadedModelPath\n'
          '  configured=${config.modelPath}\n'
          '  loaded=$_modelLoaded\n'
          '  custom=${config.isCustomToyModel}\n'
          '  fallback=$usingFallback\n'
          '  task=${task?.name ?? '-'}\n'
          '  confidenceThreshold=${config.confidenceThreshold}\n'
          '  iouThreshold=${config.iouThreshold}\n'
          '  cameraResolution=${config.cameraResolution}');
      debugPrint('[RAW] modelLoaded=true configured=${config.modelPath} '
          'loaded=$loadedModelPath task=${task?.name ?? '-'} '
          'custom=${config.isCustomToyModel} '
          'confidenceThreshold=${config.confidenceThreshold} '
          'iouThreshold=${config.iouThreshold}');
    }
  }

  void markModelReady() {
    if (state.status == ModelStatus.ready) return;
    _publish(CleanupMissionStatus.idle, status: ModelStatus.ready);
  }

  void markModelError() {
    _modelLoaded = false;
    _publish(CleanupMissionStatus.error, status: ModelStatus.error);
  }

  // ----------------------------------------------------------------
  // Child intents
  // ----------------------------------------------------------------

  /// "Nueva misión" — wipe everything and start the automatic scan for the
  /// chosen [goal] (a challenge target, not a room inventory).
  void startMission({MissionGoal goal = MissionGoal.defaultGoal}) {
    _resetInternals();
    _goal = goal;
    // Best pickup count from previous missions → the record to beat this run.
    final history = ref.read(missionHistoryProvider);
    _personalBest = history.isEmpty
        ? 0
        : history
            .map((r) => r.collectedToyCount)
            .reduce((a, b) => a > b ? a : b);
    _missionStartedAt = _clock();
    // Persist a one-shot recovery marker so an interrupted mission can be
    // recovered/closed on next launch. NOT in the per-frame loop.
    ref.read(activeMissionProvider.notifier).begin(_missionStartedAt!);
    _advanceMissionFlow(MissionFlowEvent.scanStarted);
    _startScanWindow();
    _publish(CleanupMissionStatus.scanning);
  }

  /// "Ya lo recogí" — confirm the current toy, then ALWAYS re-scan to see
  /// what is actually left in front of the camera now (fresh boxes) instead
  /// of jumping the highlight onto a stale snapshot of the next toy. The
  /// pickup itself is untouched — the toy is marked collected here; only
  /// target *selection* moves into the re-scan. Never completes here
  /// (completion is the child's explicit "No, terminé").
  void collectCurrentToy() {
    final s = state.missionStatus;
    if (s != CleanupMissionStatus.active &&
        s != CleanupMissionStatus.targetLost) {
      return;
    }
    _collectTarget(auto: false);
  }

  /// Mark the current target collected and re-scan for the next toy. Shared by
  /// the manual "Ya lo recogí" button, the automatic deduction, and the
  /// "¿Lo recogiste?" → "Sí" fallback. Never completes the mission (that is
  /// always the child's explicit "No, terminé").
  void _collectTarget({required bool auto}) {
    final id = _currentTargetId;
    final item = id != null ? _itemById(id) : null;
    if (item != null) {
      item.status = ToyItemStatus.collected;
      item.collectedAtFrame = _frame;
      if (kDebugMode) {
        debugPrint('[Tracker] Target collected: id=${_fmtId(item.toyId)}');
      }
    }
    _currentTargetId = null;
    _targetTrackId = null;
    _pendingVerificationTargetId = null;
    _sceneAnchors = const {};
    if (kDebugMode) {
      debugPrint('MissionDX: collected id=$id auto=$auto '
          'collected=${_collectedCount()} known=${_known.length} '
          'pending=${_pendingCount()}');
    }
    _advanceMissionFlow(
      MissionFlowEvent.collectionVerified,
      guardApproved: true,
    );
    // After every pickup, sweep the area: it finds the next toy OR, if the
    // floor is clean, auto-completes the mission. The happy chime is played by
    // the screen off the collected count, so both paths celebrate.
    _publish(_beginCleanAreaVerification());
  }

  /// "¿Lo recogiste?" → "Sí, lo recogí" — the manual fallback confirmation.
  void confirmPickupYes() {
    if (state.missionStatus != CleanupMissionStatus.confirmingPickup) return;
    _usedManualHelp = true;
    _collectTarget(auto: false);
  }

  /// "¿Lo recogiste?" → "Todavía no" — the toy is still there; go look for it
  /// again instead of asking repeatedly (re-scan re-finds it if present).
  void confirmPickupNo() {
    if (state.missionStatus != CleanupMissionStatus.confirmingPickup) return;
    _pendingMessage = 'Vamos a buscarlo otra vez.';
    _pendingMessageFrames = _pendingMessageDuration;
    _publish(_beginRescan(fromAsk: false));
  }

  /// "¿Ves otro juguete?" → "Sí" — point the camera and re-scan.
  void childSeesAnotherToy() {
    if (state.missionStatus != CleanupMissionStatus.askingIfMoreToys) return;
    _pendingMessage = 'Apunta la cámara al juguete.';
    _pendingMessageFrames = _pendingMessageDuration;
    _publish(_beginRescan(fromAsk: true));
  }

  /// "No, terminé" — the child's manual finish. BLOCKED while the robot still
  /// sees a toy or has one pending: we never end with toys left on the floor.
  /// Instead we sweep to pick the visible toy back up.
  void childDone() {
    final s = state.missionStatus;
    if (s != CleanupMissionStatus.askingIfMoreToys &&
        s != CleanupMissionStatus.waitingForChildTap) {
      return;
    }
    // Block ONLY when a toy is actually on screen right now (a green box / a
    // visible detection). A stale `remaining` count of known-but-unseen toys
    // must NOT trap the child in the mission — that was the "can't finish"
    // bug. Honoring the finish still respects "never complete with a toy
    // visible", because we check live visibility, not the phantom count.
    final toyVisibleNow =
        _lastVisibleIds.isNotEmpty || _lastVisionSnapshot.hasGreenOverlay;
    if (toyVisibleNow) {
      if (kDebugMode) {
        debugPrint('[Mission] Manual finish blocked: a toy is visible now '
            'visible=${_lastVisibleIds.length} '
            'green=${_lastVisionSnapshot.greenOverlayCount}');
      }
      _pendingMessage = 'Todavía veo un juguete. Vamos a recogerlo primero.';
      _pendingMessageFrames = _pendingMessageDuration;
      _publish(_beginCleanAreaVerification());
      return;
    }
    // No toy visible → honor the finish. Confirm any pending pickup (the child
    // says the floor is clear) so its +1 is not lost, then complete.
    _confirmPendingCollection();
    if (kDebugMode) {
      debugPrint('[Mission] Manual finish accepted (no toy visible): '
          'collected=${_collectedCount()} known=${_known.length}');
    }
    _recordMission(completed: true);
    _publish(CleanupMissionStatus.completed);
  }

  /// The child tapped a toy the model missed. Valid as the no-toys fallback
  /// and as live help; never steals a target that's already set.
  void addChildTapToy(double nx, double ny) {
    const allowed = {
      CleanupMissionStatus.waitingForChildTap,
      CleanupMissionStatus.askingIfMoreToys,
      CleanupMissionStatus.active,
      CleanupMissionStatus.targetLost,
    };
    if (!allowed.contains(state.missionStatus)) return;
    _usedManualHelp = true;

    // A box centered on the tap. Clamping the top-left to [0, 1-size] keeps
    // the FULL size and nudges it inward near an edge (rather than shrinking),
    // and guarantees a valid in-bounds normalized box.
    const size = 0.18;
    final rawX = nx - size / 2;
    final rawY = ny - size / 2;
    final x = rawX.clamp(0.0, 1.0 - size);
    final y = rawY.clamp(0.0, 1.0 - size);
    final id = _nextChildTapId--;
    _known.add(
      ToyMissionItem(
        toyId: id,
        source: ToySource.childTap,
        box: BoundingBox(x: x, y: y, width: size, height: size),
        orderIndex: _orderCounter++,
        firstSeenFrame: _frame,
      ),
    );
    if (_currentTargetId == null) _selectNextTarget(_lastVisibleIds);
    if (kDebugMode) {
      String f(double v) => v.toStringAsFixed(3);
      debugPrint('MissionDX: childTap id=$id '
          'normalizedTapPoint=(${f(nx)},${f(ny)}) '
          'rawBox=(${f(rawX)},${f(rawY)},$size,$size) '
          'clampedBox=(${f(x)},${f(y)},$size,$size) known=${_known.length}');
    }
    _publish(CleanupMissionStatus.active);
  }

  /// "Buscar otra vez" — the automatic-first escape from the no-toys
  /// fallback. Resets the scan attempts and sweeps again with YOLO instead
  /// of forcing the child to tap. Keeps any toys already collected.
  void restartScan() {
    final s = state.missionStatus;
    if (s != CleanupMissionStatus.waitingForChildTap &&
        s != CleanupMissionStatus.askingIfMoreToys) {
      return;
    }
    _scanAttempts = 0;
    _pendingMessage = null;
    _pendingMessageFrames = 0;
    _startScanWindow();
    _publish(CleanupMissionStatus.scanning);
  }

  /// "Necesito ayuda" — let the child tap the toy they see.
  void needHelp() {
    final s = state.missionStatus;
    if (s != CleanupMissionStatus.active &&
        s != CleanupMissionStatus.targetLost) {
      return;
    }
    _usedManualHelp = true;
    _pendingMessage = 'Toca el juguete en la pantalla.';
    _pendingMessageFrames = _pendingMessageDuration;
    _publish(CleanupMissionStatus.waitingForChildTap);
  }

  /// "Nueva misión" from completed / back-out — full wipe to idle.
  void resetMission() {
    _resetInternals();
    // Explicit user wipe — drop any recovery marker (one-shot, off the loop).
    ref.read(activeMissionProvider.notifier).clear();
    _publish(CleanupMissionStatus.idle, status: ModelStatus.ready);
  }

  /// Legacy alias.
  void reset() => resetMission();

  // ----------------------------------------------------------------
  // Helpers
  // ----------------------------------------------------------------

  void _resetInternals() {
    _tracker.reset();
    _counter.reset();
    _fusion.reset();
    _known.clear();
    _goal = MissionGoal.defaultGoal;
    _personalBest = 0;
    _currentTargetId = null;
    _targetTrackId = null;
    _targetMissedFrames = 0;
    _askResumeFrames = 0;
    _cleanAreaSweeps = 0;
    _targetLastSeenAt = null;
    _pendingVerificationTargetId = null;
    _sceneAnchors = const {};
    _orderCounter = 0;
    _nextChildTapId = -1;
    _frame = 0;
    _scanFrames = 0;
    _scanAttempts = 0;
    _rescanFromAsk = false;
    _lastVisibleIds = const {};
    _scanStartedAt = null;
    _rawTotal = 0;
    _mappedTotal = 0;
    _validTotal = 0;
    _pendingMessage = null;
    _pendingMessageFrames = 0;
    _recorded = false;
    _baselineRecorded = false;
    _baselineToyCount = null;
    _missionFlowState = MissionFlowState.scanning;
    _lastSceneStability = null;
    _lastVisionSnapshot = MissionVisionSnapshot.empty;
    _lastGuardDecision = 'notEvaluated';
    _lastGuardReason = 'missionNotEvaluatedYet';
    _lastCompletedAllowed = false;
    _lastFrameAt = null;
    _lastFrameInterval = null;
    _approxFps = null;
    _lastRawDetectionsCount = 0;
    _lastMappedDetectionsCount = 0;
    _lastValidToyCount = 0;
    _lastUnknownToyCount = 0;
    _lastRejectedDetectionsCount = 0;
    _lastRejectionReasons = const {};
    _lastDetectionDiagnostics = const [];
    _visuallyVerified = false;
    _usedManualHelp = false;
    _hadUncertainty = false;
    _sceneStability.reset();
  }

  ToyMissionItem? _itemById(int id) {
    for (final k in _known) {
      if (k.toyId == id) return k;
    }
    return null;
  }

  /// `toy_NNN` for human-readable tracker logs (matches the engine's format).
  static String _fmtId(int id) => 'toy_${id.toString().padLeft(3, '0')}';

  int _collectedCount() => _known.where((k) => k.isCollected).length;
  int _pendingCount() => _known.where((k) => k.isPending).length;
  int _remainingCount() => _known.where((k) => !k.isCollected).length;

  /// Overlay while guiding: ONLY the current target, and ONLY when there is
  /// CURRENT evidence the toy is on screen this frame. The "Recoge este" box
  /// is never painted from a stale last-known box — if the detector does not
  /// see the target right now, the box is hidden (empty list) and the robot
  /// says it is searching. A child-tapped toy is a deliberate marker the child
  /// placed, so it always shows. (During scanning the screen draws the live
  /// tracked toys directly instead of this snapshot.)
  List<TrackedToy> _overlayToys() {
    final id = _currentTargetId;
    if (id == null) return const [];
    final target = _itemById(id);
    if (target == null || target.isCollected) return const [];
    if (!_shouldShowTarget(target)) return const [];
    return [
      TrackedToy(
        id: target.toyId,
        label: 'toy',
        displayName: 'Juguete',
        box: target.box,
        confidence: target.confidence,
        framesSeen: 99,
        // Only ever built when seen this frame → always full opacity. No more
        // "fading stale box": absence of evidence hides the box outright.
        framesMissing: 0,
      ),
    ];
  }

  /// Number of toy boxes the [DetectionOverlayPainter] will paint this frame —
  /// the exact quantity the snapshot exposes as `greenOverlayCount` and the
  /// completion guard blocks on. During a scan/clean-area sweep the painter
  /// draws every visible tracked toy; while guiding it draws at most the
  /// single current target, and only when it has on-screen evidence.
  int _greenOverlayCount(CleanupMissionStatus status, Set<int> visibleIds) {
    if (status.isScanningPhase) return visibleIds.length;
    if (status.expectsCurrentTarget && _currentTargetId != null) {
      final seen = _targetTrackId != null && visibleIds.contains(_targetTrackId);
      return seen ? 1 : 0;
    }
    return 0;
  }

  /// Whether the "Recoge este" box may be painted for [target] right now:
  /// either a deliberate child-tap marker, OR the detector saw the toy within
  /// the allowed (default: zero) miss window AND it is confident enough. This
  /// is the single gate the spec asks for — no current evidence, no box.
  bool _shouldShowTarget(ToyMissionItem target) {
    if (target.source == ToySource.childTap) return true;
    final seenNow = _targetMissedFrames <= _config.targetLostFrames;
    final confident = target.confidence >= _config.targetMinVisibleConfidence;
    return seenNow && confident;
  }

  void _recordMission({required bool completed}) {
    if (_recorded) return;
    _recorded = true;
    final started = _missionStartedAt ?? _clock();
    final now = _clock();
    final collected = _collectedCount();
    final known = _known.length;
    final record = MissionRecord(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      initialToyCount: known,
      collectedToyCount: collected,
      completed: completed,
      durationSeconds: now.difference(started).inSeconds,
      starsEarned: MissionRecord.starsFor(
        completed: completed,
        initialToyCount: known,
        collectedToyCount: collected,
      ),
      visuallyVerified: _visuallyVerified,
      usedManualHelp: _usedManualHelp,
      hadUncertainty: _hadUncertainty,
      targetPickupGoal: _goal.targetPickupGoal,
    );
    ref.read(missionHistoryProvider.notifier).add(record);
    // Mission is over — clear the recovery marker (one-shot, off the loop).
    ref.read(activeMissionProvider.notifier).clear();
  }

  void _recordBaseline() {
    if (_baselineRecorded) return;
    _baselineRecorded = true;
    _baselineToyCount = _known.length;
    ref.read(activeMissionProvider.notifier).updateBaseline(
          _known.length,
          scanCompletedAt: _clock(),
          activeTargetId: _currentTargetId,
          baselineToyIds: _known.map((k) => k.toyId).toList(growable: false),
        );
  }

  void _logTarget(String why) {
    if (!kDebugMode) return;
    final t = _currentTargetId != null ? _itemById(_currentTargetId!) : null;
    debugPrint('MissionDX: target=$_currentTargetId ($why) '
        'source=${t?.source.name} box=${t?.box} '
        'known=${_known.length} pending=${_pendingCount()}');
  }

  void _advanceMissionFlow(
    MissionFlowEvent event, {
    bool sustainedLoss = false,
    bool guardApproved = false,
  }) {
    final transition = _missionStateMachine.transition(
      _missionFlowState,
      event,
      sustainedLoss: sustainedLoss,
      guardApproved: guardApproved,
    );
    if (transition.state == _missionFlowState) return;
    if (kDebugMode) {
      debugPrint('MissionFlowDX: ${transition.reason}');
    }
    _missionFlowState = transition.state;
  }

  void _recordAutoCollectGuardDecision(
    bool allowed,
    TargetCollectionEvidence evidence,
    SceneStabilityResult scene,
  ) {
    _lastGuardDecision = allowed ? 'autoCollectAllowed' : 'autoCollectBlocked';
    _lastGuardReason =
        allowed ? scene.reason.name : _autoCollectBlockReason(evidence, scene);
  }

  String _autoCollectBlockReason(
    TargetCollectionEvidence evidence,
    SceneStabilityResult scene,
  ) {
    if (evidence.missedFrames < evidence.requiredMissedFrames) {
      return 'targetLossTooBrief';
    }
    if (evidence.timeSinceLastSeen < evidence.requiredTimeSinceLastSeen) {
      return 'targetLossTooRecent';
    }
    if (scene.status != SceneStabilityStatus.stable) {
      return scene.reason.name;
    }
    if (evidence.targetStillVisibleNearby) return 'targetStillVisibleNearby';
    if (evidence.hasNewUncollectedVisible) return 'newToyVisibleInstead';
    return 'unknownAutoCollectBlock';
  }

  void _recordCompletionGuardDecision(
    bool allowed,
    MissionCompletionEvidence evidence,
  ) {
    _lastCompletedAllowed = allowed;
    _lastGuardDecision = allowed ? 'completionAllowed' : 'completionBlocked';
    _lastGuardReason =
        allowed ? 'cleanAreaVerified' : _completionBlockReason(evidence);
  }

  String _completionBlockReason(MissionCompletionEvidence evidence) {
    if (evidence.greenOverlayDetectionCount > 0) return 'greenOverlayVisible';
    if (evidence.pendingToyCount > 0) return 'pendingToysRemain';
    if (evidence.visibleToyCount > 0) return 'visibleToysRemain';
    if (evidence.validatedToyDetectionsInSweep > 0) {
      return 'validatedToysStillInSweep';
    }
    if (evidence.sawOnlyRawNonToyDetections) {
      return 'rawNonToyDetectionsAreNotCleanAreaEvidence';
    }
    if (evidence.sceneStability != SceneStabilityStatus.stable) {
      return 'sceneNotValidatedForCompletion';
    }
    return 'unknownCompletionBlock';
  }

  /// One-line diagnosis of WHERE recall fails this frame, from the detection
  /// funnel (raw → mapped → valid → visible). This is the question the recall
  /// investigation must answer: is YOLO not detecting, or is Toy Vision
  /// discarding what it detected?
  String _recallVerdict() {
    final raw = _lastRawDetectionsCount;
    final mapped = _lastMappedDetectionsCount;
    final valid = _lastValidToyCount;
    final visible = _lastVisibleIds.length;
    if (raw == 0) return 'YOLO sees nothing (blank view or model not detecting)';
    if (mapped == 0) {
      return 'YOLO sees only non-toy classes — mapper drops all ($raw raw)';
    }
    if (valid == 0) {
      return 'Mapper accepts $mapped but rules reject all (confidence/box) — '
          'app discards detected toys';
    }
    if (visible == 0) {
      return 'Toys validated ($valid) but tracker not yet stable (warming up)';
    }
    return 'OK: raw=$raw mapped=$mapped valid=$valid visible=$visible';
  }

  MissionDebugSnapshot _debugSnapshot() => MissionDebugSnapshot(
        modelLoaded: _modelLoaded,
        configuredModelPath: _activeYoloConfig.modelPath,
        loadedModelPath: _loadedModelPath,
        modelTask: _loadedModelTask,
        isCustomToyModel: _activeYoloConfig.isCustomToyModel,
        modelConfidenceThreshold: _activeYoloConfig.confidenceThreshold,
        modelIouThreshold: _activeYoloConfig.iouThreshold,
        cameraResolution: _activeYoloConfig.cameraResolution,
        loadedLabelCount: YoloDetectionMapper.diagnosticInputLabels.length,
        loadedLabelsPreview: YoloDetectionMapper.diagnosticInputLabels
            .take(12)
            .toList(growable: false),
        flowState: _missionFlowState,
        activeTargetId: _currentTargetId,
        visibleToyCount: _lastVisibleIds.length,
        baselineToyCount: _baselineToyCount,
        remainingToyCount: _remainingCount(),
        rawDetectionsCount: _lastRawDetectionsCount,
        mappedDetectionsCount: _lastMappedDetectionsCount,
        validToyCount: _lastValidToyCount,
        unknownToyCount: _lastUnknownToyCount,
        greenOverlayCount: _lastVisionSnapshot.greenOverlayCount,
        recallVerdict: _recallVerdict(),
        rejectedDetectionsCount: _lastRejectedDetectionsCount,
        rejectionReasons: _lastRejectionReasons,
        rawDetections: _lastDetectionDiagnostics,
        targetConfidence: _currentTargetId != null
            ? _itemById(_currentTargetId!)?.confidence
            : null,
        targetMissingFrameCount: _targetMissedFrames,
        frameIntervalMs: _lastFrameInterval?.inMilliseconds,
        approxFps: _approxFps,
        sceneStabilityStatus: _lastSceneStability?.status,
        sceneStabilityReason: _lastSceneStability?.reason,
        sceneStabilityScore: _lastSceneStability?.score,
        guardDecision: _lastGuardDecision,
        guardReason: _lastGuardReason,
        completedAllowed: _lastCompletedAllowed,
      );

  void _publish(
    CleanupMissionStatus next, {
    ToyCountSummary? summary,
    ModelStatus? status,
    List<TrackedToy>? overlay,
  }) {
    final collected = _collectedCount();
    final known = _known.length;
    final showTarget = next.expectsCurrentTarget ? _currentTargetId : null;
    final goal = _goal.targetPickupGoal;
    final hasReachedGoal = _goal.hasReachedGoalAt(collected);
    final isNewRecord = collected > _personalBest && collected > 0;

    var message = _guidance.message(
      missionStatus: next,
      knownCount: known,
      collectedCount: collected,
      targetPickupGoal: goal,
      pickupsToGoal: goal == null ? null : (goal - collected).clamp(0, goal),
      hasReachedGoal: hasReachedGoal,
      isNewRecord: isNewRecord,
    );
    if (_pendingMessageFrames > 0 && _pendingMessage != null) {
      message = _pendingMessage!;
      _pendingMessageFrames -= 1;
    }

    state = state.copyWith(
      status: status ?? ModelStatus.ready,
      missionStatus: next,
      visibleToys: overlay ?? _overlayToys(),
      summary: summary ?? state.summary,
      guidanceMessage: message,
      currentTargetToyId: showTarget,
      clearCurrentTarget: showTarget == null,
      knownToyCount: known,
      collectedToyCount: collected,
      currentTargetIndex: showTarget != null ? collected + 1 : collected,
      targetPickupGoal: goal,
      clearTargetPickupGoal: goal == null,
      hasReachedGoal: hasReachedGoal,
      personalBestToyCount: _personalBest,
      isNewRecord: isNewRecord,
      debugSnapshot: _debugSnapshot(),
    );
  }
}

/// Providers.
final realtimeConfigProvider = Provider<RealtimeDetectionConfig>(
  (ref) => RealtimeDetectionConfig.defaults,
);

/// Wall clock used by the time-based scan window. Overridden in tests with a
/// fake clock that advances deterministically per ingested frame.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final toyCategoryRegistryProvider = Provider<ToyCategoryRegistry>(
  (ref) => ToyCategoryRegistry.standard(),
);

final toyCleanupControllerProvider =
    NotifierProvider<ToyCleanupController, LiveDetectionState>(
  ToyCleanupController.new,
);

/// Resolves which YOLO model to use (custom toy `.tflite` if bundled, else
/// the COCO fallback). Probes the asset bundle once; the Mission screen
/// awaits it before mounting YOLOView, and the Parent panel reads it to
/// show which detector is live.
final resolvedYoloConfigProvider = FutureProvider<YoloModelConfig>(
  (ref) => YoloModelConfig.resolve(),
);
