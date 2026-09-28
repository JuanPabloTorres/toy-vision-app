import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cleanup/cleanup_event.dart';
import '../../domain/cleanup/cleanup_session.dart';
import '../../domain/scene/room_world_model.dart';
import '../../core/performance/adaptive_inference_scheduler.dart';
import '../../perception/perception_engine.dart';
import '../../perception/perception_models.dart';
import '../events/domain_event_bus.dart';
import '../feedback/encouragement_service.dart';
import '../history/cleanup_history_provider.dart';
import '../home/home_progress.dart';
import '../observability/session_evidence.dart';
import '../progress/complete_cleanup_session_use_case.dart';
import 'cleanup_session_service.dart';
import 'cleanup_state.dart';
import 'target_selector.dart';

class CleanupController extends Notifier<CleanupState> {
  late PerceptionEngine _perception;
  late CleanupSessionService _sessionService;
  late DomainEventBus _eventBus;
  late CompleteCleanupSessionUseCase _completeCleanup;
  late PerceptionEvidenceSink _evidenceSink;
  final EncouragementService _encouragement = EncouragementService();
  final TargetSelector _targetSelector = const VisibleStableTargetSelector();
  bool _processing = false;
  CameraPerceptionFrame? _pendingFrame;
  String? _persistedSessionId;
  Timer? _discoveryTransitionTimer;
  CleanupPhase? _phaseBeforePause;

  @override
  CleanupState build() {
    _perception = ref.watch(perceptionEngineProvider);
    _sessionService = CleanupSessionService();
    _eventBus = ref.watch(domainEventBusProvider);
    _completeCleanup = ref.watch(completeCleanupSessionUseCaseProvider);
    _evidenceSink = ref.watch(perceptionEvidenceSinkProvider);
    ref.onDispose(() => _discoveryTransitionTimer?.cancel());
    return const CleanupState.idle();
  }

  void start() {
    final startedAt = DateTime.now();
    final evidenceSink = _evidenceSink;
    _perception.reset();
    _sessionService.reset();
    _pendingFrame = null;
    _persistedSessionId = null;
    _discoveryTransitionTimer?.cancel();
    _phaseBeforePause = null;
    _encouragement.reset();
    unawaited(evidenceSink.startSession(startedAt));
    state = const CleanupState(
      phase: CleanupPhase.ready,
      message: '¡Vamos a recoger!',
      visionStatus: VisionStatus.initializing,
    );
  }

  void beginDiscovery() {
    if (state.phase != CleanupPhase.ready) return;
    state = state.copyWith(
      phase: CleanupPhase.discovering,
      message: 'Mueve la cámara despacito…',
    );
  }

  void _beginCleanup() {
    if (state.phase != CleanupPhase.discovering) return;
    final at = DateTime.now();
    final session = _sessionService.startCleanup(at);
    if (session == null) return;
    final target = _selectTarget(session, state.worldModel);
    state = state.copyWith(
      phase: CleanupPhase.cleaning,
      session: session,
      activeTargetTrackId: target,
      clearActiveTarget: target == null,
      message: target == null ? 'Miremos por aquí.' : '¡Vamos a recoger!',
    );
    _eventBus.publishAll([
      CleanupStarted(at),
      if (target != null) ActiveToyChanged(at, target),
    ]);
  }

  void pause() {
    if (state.phase == CleanupPhase.idle ||
        state.phase == CleanupPhase.completed ||
        state.phase == CleanupPhase.error ||
        state.phase == CleanupPhase.paused) {
      return;
    }
    _phaseBeforePause = state.phase;
    state = state.copyWith(
      phase: CleanupPhase.paused,
      visionStatus: VisionStatus.stopped,
    );
  }

  void resume() {
    if (state.phase != CleanupPhase.paused) return;
    state = state.copyWith(
      phase: _phaseBeforePause ?? CleanupPhase.ready,
      visionStatus: VisionStatus.initializing,
    );
    _phaseBeforePause = null;
  }

  void markModelReady() {
    if (state.phase == CleanupPhase.error) return;
    state = state.copyWith(
      visionStatus: VisionStatus.running,
      clearError: true,
    );
  }

  void markModelError(String message) {
    state = state.copyWith(
      phase: CleanupPhase.error,
      visionStatus: VisionStatus.error,
      message: 'No pude encender mi visión.',
      errorMessage: message,
    );
  }

  void updateDeviceHealth(DeviceHealth health) {
    _perception.updateDeviceHealth(health);
  }

  Future<void> ingest(CameraPerceptionFrame frame) async {
    if (state.visionStatus != VisionStatus.running ||
        state.phase != CleanupPhase.discovering &&
            state.phase != CleanupPhase.cleaning &&
            state.phase != CleanupPhase.verifyingRemoval &&
            state.phase != CleanupPhase.verifyingRoom) {
      return;
    }
    if (_processing) {
      _pendingFrame = frame;
      _perception.recordDroppedFrame();
      return;
    }
    _processing = true;
    var current = frame;
    try {
      while (true) {
        await _processFrame(current);
        final pending = _pendingFrame;
        _pendingFrame = null;
        if (pending == null) break;
        current = pending;
      }
    } catch (error) {
      state = state.copyWith(
        phase: CleanupPhase.error,
        visionStatus: VisionStatus.error,
        message: 'Necesito intentarlo otra vez.',
        errorMessage: error.toString(),
      );
      _eventBus.publishAll([
        PerceptionUncertain(DateTime.now(), 'pipeline_error'),
      ]);
    } finally {
      _processing = false;
    }
  }

  Future<void> _processFrame(CameraPerceptionFrame frame) async {
    final result = await _perception.processFrame(
      frame,
      discoveryMode: state.phase == CleanupPhase.discovering,
    );
    final outcome = _sessionService.process(
      result,
      allowCollection: state.phase == CleanupPhase.cleaning ||
          state.phase == CleanupPhase.verifyingRemoval ||
          state.phase == CleanupPhase.verifyingRoom,
    );
    for (final trackId in outcome.tracksToMarkCollected) {
      _perception.markCollected(trackId, frame.timestamp);
    }
    final session = outcome.session;
    final previousTarget = state.activeTargetTrackId;
    var target = previousTarget;
    if (session != null &&
        target != null &&
        session.collectedTrackIds.contains(target)) {
      target = null;
    }
    target ??= _selectTarget(session, result.worldModel);
    late final CleanupPhase phase;
    if (session?.status == CleanupStatus.completed) {
      phase = CleanupPhase.completed;
    } else if (session != null && session.remainingEstimate == 0) {
      phase = CleanupPhase.verifyingRoom;
      target = null;
    } else if (session != null) {
      final targetMissing = target != null &&
          result.worldModel.missingTracks.containsKey(target) &&
          !session.collectedTrackIds.contains(target);
      phase =
          targetMissing ? CleanupPhase.verifyingRemoval : CleanupPhase.cleaning;
    } else {
      phase = state.phase;
    }
    final frameEvents = <CleanupEvent>[
      ...outcome.events,
      if (target != null && target != previousTarget)
        ActiveToyChanged(result.worldModel.updatedAt, target),
    ];
    final completionEvents = frameEvents
        .where(
          (event) => event is RoomCleanConfirmed || event is CleanupCompleted,
        )
        .toList(growable: false);
    _eventBus.publishAll(
      frameEvents.where(
        (event) => event is! RoomCleanConfirmed && event is! CleanupCompleted,
      ),
    );
    if (session?.status == CleanupStatus.completed &&
        _persistedSessionId != session!.id) {
      await _completeCleanup(session);
      _persistedSessionId = session.id;
      ref.invalidate(homeProgressProvider);
      _eventBus.publishAll(completionEvents);
    }
    await _evidenceSink.record(
      SessionEvidenceFrame(
        frame: frame,
        perception: result,
        events: frameEvents,
        session: session,
        completionEvidence: outcome.completionEvidence,
      ),
    );
    state = state.copyWith(
      phase: phase,
      worldModel: result.worldModel,
      initialSnapshot: outcome.initialSnapshot,
      session: session,
      metrics: result.metrics,
      latestPerception: result,
      discoveryProgress: outcome.discoveryProgress,
      completionEvidence: outcome.completionEvidence,
      activeTargetTrackId: target,
      clearActiveTarget: target == null,
      message: _messageFor(
        phase,
        frameEvents,
        result,
        target: target,
        session: session,
      ),
      visionStatus: phase == CleanupPhase.completed
          ? VisionStatus.stopped
          : VisionStatus.running,
      clearError: true,
    );
    if (phase == CleanupPhase.discovering &&
        outcome.initialSnapshot != null &&
        _discoveryTransitionTimer == null) {
      final count = outcome.initialSnapshot!.toys.length;
      state = state.copyWith(
        message: '¡Encontré $count ${count == 1 ? 'juguete' : 'juguetes'}!',
      );
      _discoveryTransitionTimer = Timer(const Duration(seconds: 1), () {
        _discoveryTransitionTimer = null;
        _beginCleanup();
      });
    }
  }

  int? _selectTarget(CleanupSession? session, RoomWorldModel? worldModel) {
    final snapshot = _sessionService.snapshot;
    if (session == null || snapshot == null || worldModel == null) return null;
    return _targetSelector.selectNext(
      snapshot: snapshot,
      tracking: worldModel,
      excludedTrackIds: session.collectedTrackIds,
    );
  }

  String _messageFor(
    CleanupPhase phase,
    List<CleanupEvent> events,
    PerceptionResult perception, {
    required int? target,
    required CleanupSession? session,
  }) {
    if (phase == CleanupPhase.ready) return '¡Vamos a recoger!';
    if (phase == CleanupPhase.discovering) return 'Buscando juguetes…';
    if (phase == CleanupPhase.completed) return '¡Lo lograste!';
    if (phase == CleanupPhase.verifyingRoom) {
      return 'Déjame mirar una vez más…';
    }
    if (phase == CleanupPhase.verifyingRemoval) {
      return perception.worldModel.scene.canVerifyDisappearance
          ? '✨ Hmm…'
          : 'Miremos por aquí.';
    }
    if (events.any((event) => event is NewToyDiscovered)) {
      return '¡Mira! Encontré otro.';
    }
    if (events.any((event) => event is ToyCollected)) {
      return _encouragement.next();
    }
    if (phase == CleanupPhase.cleaning && target == null) {
      return 'Miremos por aquí.';
    }
    if (phase == CleanupPhase.cleaning && session?.remainingEstimate == 1) {
      return '¡Solo queda uno!';
    }
    if (events.any((event) => event is RoomAlmostClean)) {
      return '¡Cada vez quedan menos!';
    }
    return '¡Sigue así!';
  }

  void reset() {
    _perception.reset();
    _sessionService.reset();
    _pendingFrame = null;
    _discoveryTransitionTimer?.cancel();
    _discoveryTransitionTimer = null;
    _phaseBeforePause = null;
    state = const CleanupState.idle();
  }
}

final perceptionEngineProvider = Provider<PerceptionEngine>((ref) {
  return HybridToyPerceptionEngine();
});

final domainEventBusProvider = Provider<DomainEventBus>((ref) {
  final bus = DomainEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final perceptionEvidenceSinkProvider = Provider<PerceptionEvidenceSink>(
  (ref) => const DisabledPerceptionEvidenceSink(),
);

final cleanupControllerProvider =
    NotifierProvider<CleanupController, CleanupState>(CleanupController.new);
