import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/mission_state_machine.dart';

void main() {
  const machine = MissionStateMachine();

  test('scan completed then target selected enters active target', () {
    final ready = machine.transition(
      MissionFlowState.scanning,
      MissionFlowEvent.scanCompleted,
    );
    expect(ready.state, MissionFlowState.ready);

    final active = machine.transition(
      ready.state,
      MissionFlowEvent.targetSelected,
    );
    expect(active.state, MissionFlowState.activeTarget);
  });

  test('targetLost never means targetCollected by itself', () {
    final transition = machine.transition(
      MissionFlowState.activeTarget,
      MissionFlowEvent.targetLost,
    );

    expect(transition.state, MissionFlowState.targetTemporarilyMissing);
    expect(transition.state, isNot(MissionFlowState.targetCollected));
  });

  test('target lost plus camera moved requests a rescan', () {
    final transition = machine.transition(
      MissionFlowState.targetTemporarilyMissing,
      MissionFlowEvent.sceneMoved,
    );

    expect(transition.state, MissionFlowState.needsRescan);
  });

  test('stable sustained target loss enters collection verification', () {
    final waiting = machine.transition(
      MissionFlowState.targetTemporarilyMissing,
      MissionFlowEvent.sceneStable,
      sustainedLoss: false,
    );
    expect(waiting.state, MissionFlowState.targetTemporarilyMissing);

    final verifying = machine.transition(
      MissionFlowState.targetTemporarilyMissing,
      MissionFlowEvent.sceneStable,
      sustainedLoss: true,
    );
    expect(verifying.state, MissionFlowState.verifyingCollection);
  });

  test('verifying collection requires guard approval', () {
    final rejected = machine.transition(
      MissionFlowState.verifyingCollection,
      MissionFlowEvent.collectionVerified,
      guardApproved: false,
    );
    expect(rejected.state, MissionFlowState.targetTemporarilyMissing);

    final collected = machine.transition(
      MissionFlowState.verifyingCollection,
      MissionFlowEvent.collectionVerified,
      guardApproved: true,
    );
    expect(collected.state, MissionFlowState.targetCollected);
  });

  test('remaining visible toys go to next target instead of completed', () {
    final transition = machine.transition(
      MissionFlowState.targetCollected,
      MissionFlowEvent.visibleToysRemaining,
    );

    expect(transition.state, MissionFlowState.lookingForNextTarget);
    expect(transition.state, isNot(MissionFlowState.completed));
  });

  test('completion only happens from clean area verification with guard', () {
    final blocked = machine.transition(
      MissionFlowState.cleanAreaVerification,
      MissionFlowEvent.missionCompleted,
      guardApproved: false,
    );
    expect(blocked.state, MissionFlowState.cleanAreaVerification);

    final completed = machine.transition(
      MissionFlowState.cleanAreaVerification,
      MissionFlowEvent.missionCompleted,
      guardApproved: true,
    );
    expect(completed.state, MissionFlowState.completed);
  });
}
