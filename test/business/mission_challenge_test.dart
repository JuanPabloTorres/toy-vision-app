import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/cleanup_mission_status.dart';
import 'package:toyvision_realtime/business/mission/mission_goal.dart';
import 'package:toyvision_realtime/camera/controllers/toy_cleanup_controller.dart';
import 'package:toyvision_realtime/storage/mission_history_repository.dart';
import 'package:toyvision_realtime/storage/mission_record.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Tests for the **challenge / record** product model: the basket counts
/// confirmed pickups toward a CHALLENGE goal (3/5/10/free), reaching the goal
/// celebrates but does not end the mission, and surpassing the previous best
/// sets a new record. The goal is NEVER a room inventory.

YOLOResult _teddyBear({
  int classIndex = 1,
  double x = 0.2,
  double size = 0.12,
  double confidence = 0.85,
}) =>
    YOLOResult(
      classIndex: classIndex,
      className: 'teddy bear',
      confidence: confidence,
      boundingBox: const Rect.fromLTWH(200, 200, 120, 120),
      normalizedBox: Rect.fromLTWH(x, 0.2, size, size),
    );

/// A chair: real context the toy mapper DROPS, so the camera "sees the area"
/// (rawCount > 0 → a clean, seen area) without producing a valid toy.
YOLOResult _chair({double x = 0.6}) => YOLOResult(
      classIndex: 56,
      className: 'chair',
      confidence: 0.8,
      boundingBox: const Rect.fromLTWH(200, 200, 300, 300),
      normalizedBox: Rect.fromLTWH(x, 0.2, 0.3, 0.3),
    );

void main() {
  group('MissionGoal model', () {
    test('challenge targets: quick=3, normal=5, super=10, record=free', () {
      expect(MissionGoal.quick.targetPickupGoal, 3);
      expect(MissionGoal.normal.targetPickupGoal, 5);
      expect(MissionGoal.superChallenge.targetPickupGoal, 10);
      expect(MissionGoal.record.targetPickupGoal, isNull);
      expect(MissionGoal.record.isRecordMode, isTrue);
      expect(MissionGoal.defaultGoal, MissionGoal.normal);
    });

    test('hasReachedGoalAt compares against goal; free mode never reaches', () {
      expect(MissionGoal.quick.hasReachedGoalAt(2), isFalse);
      expect(MissionGoal.quick.hasReachedGoalAt(3), isTrue);
      expect(MissionGoal.quick.hasReachedGoalAt(5), isTrue);
      expect(MissionGoal.record.hasReachedGoalAt(99), isFalse);
    });

    test('fromTarget round-trips persisted goals', () {
      expect(MissionGoal.fromTarget(3).challenge, MissionChallenge.quick);
      expect(MissionGoal.fromTarget(5).challenge, MissionChallenge.normal);
      expect(
        MissionGoal.fromTarget(10).challenge,
        MissionChallenge.superChallenge,
      );
      expect(MissionGoal.fromTarget(null).challenge, MissionChallenge.record);
    });
  });

  group('challenge counting (controller)', () {
    var now = DateTime(2026, 6, 5, 12);

    ProviderContainer container() {
      now = DateTime(2026, 6, 5, 12);
      return ProviderContainer(
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
    }

    void feed(ToyCleanupController c, List<YOLOResult> frame, int times) {
      for (var i = 0; i < times; i++) {
        now = now.add(const Duration(milliseconds: 250));
        c.ingest(frame);
      }
    }

    // n distinct, in-frame toys (≈0.19 apart so tracking/dedup never merges).
    List<YOLOResult> nToys(int n) => [
          for (var i = 0; i < n; i++)
            _teddyBear(classIndex: i + 1, x: 0.03 + i * 0.19),
        ];

    ToyCleanupController activeWith(
      ProviderContainer c, {
      MissionGoal goal = MissionGoal.normal,
      int n = 1,
    }) {
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission(goal: goal);
      feed(ctrl, nToys(n), 34);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.active,
      );
      return ctrl;
    }

    MissionRecord seed({required int collected}) => MissionRecord(
          id: 'seed-$collected',
          date: DateTime(2026, 6, 1),
          initialToyCount: collected,
          collectedToyCount: collected,
          completed: true,
          durationSeconds: 30,
          starsEarned: 1,
        );

    test('mission starts at collectedToyCount = 0 with the chosen goal', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission(goal: MissionGoal.quick);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 0);
      expect(s.targetPickupGoal, 3);
      expect(s.hasReachedGoal, isFalse);
    });

    test('default mission is normal (goal = 5)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      expect(c.read(toyCleanupControllerProvider).targetPickupGoal, 5);
    });

    test('detecting toys does NOT increment the basket', () {
      final c = container();
      addTearDown(c.dispose);
      activeWith(c, goal: MissionGoal.normal, n: 2);
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 0);
    });

    test('a confirmed pickup increments the basket immediately by +1', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.normal, n: 2);
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 0);
      ctrl.collectCurrentToy(); // confirmed pickup
      // Updates synchronously — no extra frames needed.
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 1);
    });

    test(
        'reaching the goal sets hasReachedGoal but does NOT complete while '
        'toys are still visible', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 4); // goal 3
      for (var i = 0; i < 3; i++) {
        ctrl.collectCurrentToy();
        feed(ctrl, nToys(4), 24); // a 4th toy is always still in view
      }
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 3);
      expect(s.hasReachedGoal, isTrue);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('after reaching the goal the basket keeps counting past it', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 4); // goal 3
      for (var i = 0; i < 4; i++) {
        ctrl.collectCurrentToy();
        feed(ctrl, nToys(4), 24);
      }
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 4); // surpassed the goal of 3
      expect(s.hasReachedGoal, isTrue);
    });

    test('surpassing the previous best marks a new record', () {
      final c = container();
      addTearDown(c.dispose);
      c.read(missionHistoryProvider.notifier).add(seed(collected: 1));
      final ctrl = activeWith(c, goal: MissionGoal.normal, n: 3);
      expect(c.read(toyCleanupControllerProvider).personalBestToyCount, 1);

      ctrl.collectCurrentToy();
      feed(ctrl, nToys(3), 24); // count 1 == best, not yet a record
      expect(c.read(toyCleanupControllerProvider).isNewRecord, isFalse);

      ctrl.collectCurrentToy();
      feed(ctrl, nToys(3), 24); // count 2 > best 1 → new record
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 2);
      expect(s.isNewRecord, isTrue);
    });

    test('ONE clean window does NOT finish — no premature 1/3 finish; the '
        'mission keeps searching automatically', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 1); // goal 3
      ctrl.collectCurrentToy(); // 1/3 → clean-area search
      feed(ctrl, [_chair()], 14); // ~ONE clean window only
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus,
        isNot(CleanupMissionStatus.completed),
        reason: 'one clean frame must not end the challenge at 1/3',
      );
      expect(s.missionStatus.isScanningPhase, isTrue);
    });

    test('a goal challenge does NOT finish on a clean area below the goal — it '
        'holds in needsMoreToysForGoal (the "completed at 1/3" bug)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 1); // goal 3
      ctrl.collectCurrentToy(); // 1/3
      feed(ctrl, [_chair()], 30); // sustained clean — but goal NOT reached
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus,
        isNot(CleanupMissionStatus.completed),
        reason: 'a fixed-goal challenge can never complete below the goal',
      );
      expect(s.missionStatus, CleanupMissionStatus.needsMoreToysForGoal);
    });

    test('FREE/record mode DOES finish by itself once the area is clean long '
        'enough (no fixed goal to gate on)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.record, n: 1);
      ctrl.collectCurrentToy(); // 1 collected, no goal
      feed(ctrl, [_chair()], 30); // sustained clean (≥2 windows) → auto-complete
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus,
        CleanupMissionStatus.completed,
        reason: 'free mode finishes on a verified clean area without a goal',
      );
    });

    test('once the goal IS reached, a clean area auto-completes promptly', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 4); // goal 3
      for (var i = 0; i < 3; i++) {
        ctrl.collectCurrentToy();
        if (i < 2) feed(ctrl, nToys(4), 24); // a toy stays visible until 3/3
      }
      // 3/3 reached; now the area goes clean → it may finish.
      feed(ctrl, [_chair()], 30);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 3);
      expect(s.hasReachedGoal, isTrue);
      expect(s.missionStatus, CleanupMissionStatus.completed);
    });

    test('between toys, pointing at another toy resumes the hunt automatically',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.quick, n: 1); // goal 3
      ctrl.collectCurrentToy(); // 1/3 → searching
      feed(ctrl, [_chair()], 14); // brief clean → still searching (not done)
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        isNot(CleanupMissionStatus.completed),
      );
      // The child simply points at the next toy — the search finds it on its
      // own; no "Sí, veo otro" tap needed.
      feed(ctrl, [_teddyBear(x: 0.5)], 24);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.active,
        reason: 'a visible toy resumes the search automatically',
      );
    });

    test('the same target is never counted twice', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, goal: MissionGoal.normal, n: 2);
      ctrl.collectCurrentToy();
      final after = c.read(toyCleanupControllerProvider).collectedToyCount;
      // Keep feeding the SAME toys; a collected one must not be re-counted.
      feed(ctrl, nToys(2), 30);
      expect(
        c.read(toyCleanupControllerProvider).collectedToyCount,
        after,
        reason: 'a collected toy cannot be counted again',
      );
    });
  });

  // The reported bug: the mission was declared complete at 1/5 or 3/5. The
  // ABSOLUTE rule is `missionCompleted = false` while collectedToyCount <
  // targetPickupGoal, regardless of a clean area, no toys visible, or "Terminé".
  group('goal gate — completion blocked below the goal (reported bug)', () {
    var now = DateTime(2026, 6, 5, 12);

    ProviderContainer container() {
      now = DateTime(2026, 6, 5, 12);
      return ProviderContainer(
        overrides: [clockProvider.overrideWithValue(() => now)],
      );
    }

    void feed(ToyCleanupController c, List<YOLOResult> frame, int times) {
      for (var i = 0; i < times; i++) {
        now = now.add(const Duration(milliseconds: 250));
        c.ingest(frame);
      }
    }

    // [collect] distinct, in-frame toys (≈0.19 apart so tracking never merges).
    List<YOLOResult> nToys(int n) => [
          for (var i = 0; i < n; i++)
            _teddyBear(classIndex: i + 1, x: 0.03 + i * 0.19),
        ];

    /// Start a [goal] mission, collect [collect] distinct toys, then leave the
    /// floor clean (a chair = area seen but no valid toy). Returns the
    /// controller in whatever state the clean sweep settled into.
    ToyCleanupController collectThenClean(
      ProviderContainer c, {
      required MissionGoal goal,
      required int collect,
      int cleanFrames = 30,
    }) {
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission(goal: goal);
      feed(ctrl, nToys(collect), 34);
      for (var i = 0; i < collect; i++) {
        ctrl.collectCurrentToy();
        if (i < collect - 1) feed(ctrl, nToys(collect), 24);
      }
      feed(ctrl, [_chair()], cleanFrames); // area seen + clean
      return ctrl;
    }

    test('mission 5: starts at 0/5 and is not completed', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission(goal: MissionGoal.normal);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 0);
      expect(s.targetPickupGoal, 5);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('collected 1 / goal 5 + clean area → NOT completed', () {
      final c = container();
      addTearDown(c.dispose);
      collectThenClean(c, goal: MissionGoal.normal, collect: 1);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(s.missionStatus, CleanupMissionStatus.needsMoreToysForGoal);
    });

    test('collected 3 / goal 5 + clean area → NOT completed', () {
      final c = container();
      addTearDown(c.dispose);
      collectThenClean(c, goal: MissionGoal.normal, collect: 3);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 3);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(s.missionStatus, CleanupMissionStatus.needsMoreToysForGoal);
    });

    test('collected 5 / goal 5 + clean area → completed', () {
      final c = container();
      addTearDown(c.dispose);
      collectThenClean(c, goal: MissionGoal.normal, collect: 5);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 5);
      expect(s.hasReachedGoal, isTrue);
      expect(s.missionStatus, CleanupMissionStatus.completed);
      // Saved as a completed run.
      final history = c.read(missionHistoryProvider);
      expect(history, hasLength(1));
      expect(history.single.completed, isTrue);
      expect(history.single.collectedToyCount, 5);
    });

    test('no more toys visible but goal not met → needsMoreToysForGoal', () {
      final c = container();
      addTearDown(c.dispose);
      collectThenClean(c, goal: MissionGoal.normal, collect: 2);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.needsMoreToysForGoal,
      );
    });

    test('pressing Terminé at 3/5 does NOT complete and saves nothing', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = collectThenClean(c, goal: MissionGoal.normal, collect: 3);
      ctrl.childDone(); // explicit finish below the goal
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 3);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(
        c.read(missionHistoryProvider),
        isEmpty,
        reason: 'a 3/5 mission must never be saved as completed',
      );
    });

    test('record/free mode finishes by itself on a clean area (no goal gate)',
        () {
      final c = container();
      addTearDown(c.dispose);
      collectThenClean(c, goal: MissionGoal.record, collect: 2);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 2);
      expect(s.missionStatus, CleanupMissionStatus.completed);
    });
  });
}
