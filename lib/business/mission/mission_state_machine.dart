enum MissionFlowState {
  scanning,
  ready,
  activeTarget,
  targetTemporarilyMissing,
  verifyingCollection,
  targetCollected,
  lookingForNextTarget,
  needsRescan,
  cleanAreaVerification,
  completed,
}

enum MissionFlowEvent {
  scanStarted,
  scanCompleted,
  targetSelected,
  targetSeen,
  targetLost,
  sceneStable,
  sceneMoved,
  collectionVerified,
  collectionRejected,
  visibleToysRemaining,
  noToysVisible,
  missionCompleted,
  rescanRequested,
}

class MissionFlowTransition {
  const MissionFlowTransition({
    required this.state,
    required this.reason,
  });

  final MissionFlowState state;
  final String reason;
}

class MissionStateMachine {
  const MissionStateMachine();

  MissionFlowTransition transition(
    MissionFlowState current,
    MissionFlowEvent event, {
    bool sustainedLoss = false,
    bool guardApproved = false,
  }) {
    final next = switch ((current, event)) {
      (_, MissionFlowEvent.scanStarted) => MissionFlowState.scanning,
      (_, MissionFlowEvent.rescanRequested) => MissionFlowState.needsRescan,
      (MissionFlowState.scanning, MissionFlowEvent.scanCompleted) =>
        MissionFlowState.ready,
      (MissionFlowState.ready, MissionFlowEvent.targetSelected) =>
        MissionFlowState.activeTarget,
      (
        MissionFlowState.lookingForNextTarget,
        MissionFlowEvent.targetSelected
      ) =>
        MissionFlowState.activeTarget,
      (MissionFlowState.activeTarget, MissionFlowEvent.targetSeen) =>
        MissionFlowState.activeTarget,
      (
        MissionFlowState.targetTemporarilyMissing,
        MissionFlowEvent.targetSeen
      ) =>
        MissionFlowState.activeTarget,
      (MissionFlowState.activeTarget, MissionFlowEvent.targetLost) =>
        MissionFlowState.targetTemporarilyMissing,
      (
        MissionFlowState.targetTemporarilyMissing,
        MissionFlowEvent.sceneMoved
      ) =>
        MissionFlowState.needsRescan,
      (
        MissionFlowState.targetTemporarilyMissing,
        MissionFlowEvent.sceneStable
      ) =>
        sustainedLoss
            ? MissionFlowState.verifyingCollection
            : MissionFlowState.targetTemporarilyMissing,
      (
        MissionFlowState.verifyingCollection,
        MissionFlowEvent.collectionVerified
      ) =>
        guardApproved
            ? MissionFlowState.targetCollected
            : MissionFlowState.targetTemporarilyMissing,
      (
        MissionFlowState.verifyingCollection,
        MissionFlowEvent.collectionRejected
      ) =>
        MissionFlowState.targetTemporarilyMissing,
      (
        MissionFlowState.targetCollected,
        MissionFlowEvent.visibleToysRemaining
      ) =>
        MissionFlowState.lookingForNextTarget,
      (MissionFlowState.targetCollected, MissionFlowEvent.noToysVisible) =>
        MissionFlowState.cleanAreaVerification,
      (
        MissionFlowState.cleanAreaVerification,
        MissionFlowEvent.visibleToysRemaining
      ) =>
        MissionFlowState.lookingForNextTarget,
      (
        MissionFlowState.cleanAreaVerification,
        MissionFlowEvent.missionCompleted
      ) =>
        guardApproved
            ? MissionFlowState.completed
            : MissionFlowState.cleanAreaVerification,
      _ => current,
    };

    return MissionFlowTransition(
      state: next,
      reason: '${current.name}.${event.name}->${next.name}',
    );
  }
}
