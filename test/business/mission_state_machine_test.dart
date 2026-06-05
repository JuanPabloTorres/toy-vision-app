import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/cleanup_mission_status.dart';
import 'package:toyvision_realtime/business/mission/mission_goal.dart';
import 'package:toyvision_realtime/camera/controllers/toy_cleanup_controller.dart';
import 'package:toyvision_realtime/storage/active_mission_repository.dart';
import 'package:toyvision_realtime/storage/mission_history_repository.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Integration guards for the Phase 7 **automatic, progressive** mission
/// flow: scan → guide one toy at a time → re-scan → ask "¿ves otro?" →
/// complete only on the child's confirmation. The robot guides; the model
/// only helps find toys.

YOLOResult _teddyBear({
  int classIndex = 1,
  double x = 0.2,
  double y = 0.2,
  double size = 0.3,
  double confidence = 0.85,
}) {
  return YOLOResult(
    classIndex: classIndex,
    className: 'teddy bear',
    confidence: confidence,
    boundingBox: const Rect.fromLTWH(200, 200, 300, 300),
    normalizedBox: Rect.fromLTWH(x, y, size, size),
  );
}

/// A real detection the toy mapper DROPS (a chair) — gives "the camera sees
/// context" (rawCount > 0) without producing a valid toy candidate.
YOLOResult _chair({double x = 0.6, double size = 0.3}) {
  return YOLOResult(
    classIndex: 56,
    className: 'chair',
    confidence: 0.8,
    boundingBox: const Rect.fromLTWH(200, 200, 300, 300),
    normalizedBox: Rect.fromLTWH(x, 0.2, size, size),
  );
}

YOLOResult _genericToy({
  double x = 0.2,
  double y = 0.2,
  double size = 0.3,
  double confidence = 0.78,
}) {
  return YOLOResult(
    classIndex: 0,
    className: 'toy',
    confidence: confidence,
    boundingBox: const Rect.fromLTWH(200, 200, 300, 300),
    normalizedBox: Rect.fromLTWH(x, y, size, size),
  );
}

void main() {
  // Scan windows are time-based; drive a fake clock that advances 250ms per
  // ingested frame so the windows (5s initial / 3s rescan) close
  // deterministically in tests.
  var now = DateTime(2026, 6, 2, 12);

  ProviderContainer container() {
    now = DateTime(2026, 6, 2, 12);
    return ProviderContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
  }

  // Each frame advances the fake clock — ~24 frames closes the 5s scan.
  void feed(ToyCleanupController c, List<YOLOResult> frame, int times) {
    for (var i = 0; i < times; i++) {
      now = now.add(const Duration(milliseconds: 250));
      c.ingest(frame);
    }
  }

  /// Drives the controller to an active mission with [n] teddy bears.
  // These flow-machinery tests exercise the clean-area COMPLETION path, which
  // (in the challenge model) auto-completes in free/record mode — the goal gate
  // itself is covered in mission_challenge_test. So start missions in free mode
  // here to test completion without a pickup goal interfering.
  ToyCleanupController activeWith(ProviderContainer c, {int n = 2}) {
    final ctrl = c.read(toyCleanupControllerProvider.notifier);
    ctrl.markModelReady();
    ctrl.startMission(goal: MissionGoal.record);
    final frame = [
      for (var i = 0; i < n; i++)
        _teddyBear(classIndex: i + 1, x: 0.15 + i * 0.3),
    ];
    feed(ctrl, frame, 34); // close the scan window (30 frames + margin)
    final s = c.read(toyCleanupControllerProvider);
    expect(s.missionStatus, CleanupMissionStatus.active);
    return ctrl;
  }

  group('startup / scanning', () {
    test('boots idle and stays idle until startMission', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      feed(ctrl, [_teddyBear()], 10);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.idle,
      );
    });

    test('startMission scans automatically and finds toys → active', () {
      final c = container();
      addTearDown(c.dispose);
      activeWith(c, n: 2);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.knownToyCount, 2);
      expect(s.currentTargetToyId, isNotNull);
      expect(s.currentTargetIndex, 1);
      expect(s.collectedToyCount, 0);
      final active = c.read(activeMissionProvider);
      expect(active, isNotNull);
      expect(active!.baselineToyCount, 2);
      expect(active.scanCompletedAt, isNotNull);
      expect(active.activeTargetId, s.currentTargetToyId);
      expect(active.baselineToyIds, hasLength(2));
    });

    test('debug snapshot exposes real-device calibration signals', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();

      feed(ctrl, [_genericToy()], 34);
      var s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.knownToyCount, 1);
      expect(s.debugSnapshot, isNotNull);
      expect(s.debugSnapshot!.rawDetectionsCount, 1);
      expect(s.debugSnapshot!.validToyCount, 1);
      expect(s.debugSnapshot!.unknownToyCount, 1);
      expect(s.debugSnapshot!.targetConfidence, closeTo(0.78, 0.01));
      expect(s.debugSnapshot!.approxFps, greaterThan(0));

      feed(ctrl, const [], 4);
      s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.targetLost);
      expect(s.debugSnapshot!.targetMissingFrameCount, greaterThan(0));
      expect(s.debugSnapshot!.rawDetectionsCount, 0);
      expect(s.debugSnapshot!.validToyCount, 0);
    });

    test('a SINGLE brief detection is still presented to collect', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // The model glimpses one toy in a SINGLE frame, then loses it for the
      // rest of the scan window. It must still become a presented target (not
      // fall through to the tap fallback). Because it is then unseen for a
      // while, live guidance shows it as `targetLost` ("buscando"), but a
      // highlighted target is still presented — that is what matters here.
      feed(ctrl, [_teddyBear()], 1);
      // Enough empty frames to close the 5s scan window (≈20 frames) and
      // present the target, but fewer than the auto-collect threshold so it is
      // still shown as `targetLost` rather than being deduced as picked up.
      feed(ctrl, const [], 23);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus.expectsCurrentTarget, isTrue);
      expect(s.missionStatus, isNot(CleanupMissionStatus.waitingForChildTap));
      expect(s.currentTargetToyId, isNotNull);
      expect(s.knownToyCount, 1);
    });

    test('DURING the scan, live detections are drawn (immediate feedback)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // A SINGLE frame — before the candidate has stabilized
      // (_minCandidateFrames), so the one-pass gate has not selected yet. The
      // child must already see boxes while the robot is still scanning.
      feed(ctrl, [_teddyBear(x: 0.3), _teddyBear(classIndex: 2, x: 0.7)], 1);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.scanning);
      expect(
        s.visibleToys,
        isNotEmpty,
        reason: 'The child must see boxes while the robot is scanning.',
      );
    });

    test('ONE-PASS: a stable candidate is selected the instant it appears '
        '(no waiting out the scan window)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // Just _minCandidateFrames frames of a clearly-visible toy — far fewer
      // than the ~20 frames the old 5s scan window took — must already lock a
      // target. Detect and select happen in the same pass.
      feed(ctrl, [_teddyBear(x: 0.4)], 2);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.currentTargetToyId, isNotNull);
    });
  });

  group('overlay shows ONLY with current evidence', () {
    test('a seen target is drawn and moves with the toy (same target)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      final s0 = c.read(toyCleanupControllerProvider);
      final targetId = s0.currentTargetToyId;
      expect(s0.shouldShowTargetOverlay, isTrue);
      final startCenter =
          s0.visibleToys.firstWhere((t) => t.id == targetId).box.centerX;

      // Toy slides across the frame, seen every frame → box follows it.
      for (var i = 0; i < 12; i++) {
        feed(ctrl, [_teddyBear(x: 0.15 + i * 0.03)], 1);
      }
      feed(ctrl, [_teddyBear(x: 0.51)], 4);

      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(
        s.currentTargetToyId,
        targetId,
        reason: 'following a toy must not change which toy is the target',
      );
      expect(s.shouldShowTargetOverlay, isTrue);
      final endCenter =
          s.visibleToys.firstWhere((t) => t.id == targetId).box.centerX;
      expect(endCenter, greaterThan(startCenter + 0.15));
    });

    test('camera leaves the toy → box HIDDEN, target kept, never completes',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      final targetId = c.read(toyCleanupControllerProvider).currentTargetToyId;

      // Camera on a wall / empty floor: a few frames with no valid detection.
      feed(ctrl, const [], 4);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.targetLost);
      expect(
        s.shouldShowTargetOverlay,
        isFalse,
        reason: 'no current detection → the "Recoge este" box must disappear',
      );
      expect(s.visibleToys.any((t) => t.id == targetId), isFalse);
      expect(
        s.currentTargetToyId,
        targetId,
        reason: 'losing sight is NOT collecting — the selection persists',
      );
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('a different toy passing by never hijacks the hidden target', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // target near x≈0.15
      final targetId = c.read(toyCleanupControllerProvider).currentTargetToyId;

      feed(ctrl, const [], 4); // lose it → targetLost, box hidden
      expect(
        c.read(toyCleanupControllerProvider).shouldShowTargetOverlay,
        isFalse,
      );

      // A DIFFERENT toy appears on the far side (still under the rescan window).
      feed(ctrl, [_teddyBear(classIndex: 5, x: 0.65)], 3);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.currentTargetToyId,
        targetId,
        reason: 'a far, unrelated toy must not become the target',
      );
      expect(
        s.shouldShowTargetOverlay,
        isFalse,
        reason: 'the yellow box must not jump onto a different toy',
      );
    });

    test('the target reappears → recovered, same id, box restored', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      final targetId = c.read(toyCleanupControllerProvider).currentTargetToyId;

      feed(ctrl, const [], 4); // lost → hidden
      expect(
        c.read(toyCleanupControllerProvider).shouldShowTargetOverlay,
        isFalse,
      );

      feed(ctrl, [_teddyBear(x: 0.2)], 2); // the SAME toy comes back
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.currentTargetToyId, targetId);
      expect(s.shouldShowTargetOverlay, isTrue);
    });

    test('a long loss auto-collects the toy, then keeps searching — never '
        'freezes the box, never completes on a blank view', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);

      // The lone toy is gone for a long time → deduced as a pickup (+1), then
      // the robot keeps sweeping for the next toy. It never freezes a target
      // box and never completes on a blank/covered view.
      feed(ctrl, const [], 30);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus.isScanningPhase,
        isTrue,
        reason: 'after the pickup it keeps hunting, not a frozen target',
      );
      expect(s.shouldShowTargetOverlay, isFalse);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });
  });

  group('automatic collection (deduce a pickup)', () {
    // Two toys far apart so neither tracking nor the "near" guard confuses
    // them: a left TARGET and a right ANCHOR that stays in view.
    YOLOResult target() => _teddyBear(classIndex: 1, x: 0.12);
    YOLOResult anchor() => _teddyBear(classIndex: 2, x: 0.62);

    ToyCleanupController twoToysActive(ProviderContainer c) {
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      feed(ctrl, [target(), anchor()], 34); // scan → active (target = left)
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.active,
      );
      feed(ctrl, [target(), anchor()], 3); // a few frames → capture anchors
      return ctrl;
    }

    test('toy lifted away while the scene stays → auto-collected + advances',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = twoToysActive(c);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;

      // The child lifts the TARGET; the rest of the scene (anchor) is steady.
      feed(ctrl, [anchor()], 30);

      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.collectedToyCount,
        1,
        reason: 'a removed toy in a steady scene is auto-collected',
      );
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(
        s.currentTargetToyId,
        isNot(original),
        reason: 'it advances to the remaining toy, not the same one',
      );
    });

    test('camera pans to a new area → NOT auto-collected (re-scans instead)',
        () {
      final c = container();
      addTearDown(c.dispose);
      // Target left, anchor mid; both leave when we pan right to a new toy.
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      feed(
        ctrl,
        [
          _teddyBear(classIndex: 1, x: 0.05),
          _teddyBear(classIndex: 2, x: 0.30),
        ],
        34,
      );
      feed(
        ctrl,
        [
          _teddyBear(classIndex: 1, x: 0.05),
          _teddyBear(classIndex: 2, x: 0.30),
        ],
        3,
      );

      // Pan away: old objects gone, a different toy appears far to the right.
      feed(ctrl, [_teddyBear(classIndex: 7, x: 0.65)], 30);

      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.collectedToyCount,
        0,
        reason: 'a camera pan must never be read as a pickup',
      );
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('target reappears before the threshold → recovered, NOT collected',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = twoToysActive(c);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;

      feed(ctrl, [anchor()], 8); // lost, but under the auto-collect threshold
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 0);

      feed(ctrl, [target(), anchor()], 3); // the SAME toy comes back
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.collectedToyCount,
        0,
        reason: 'reappearing cancels auto-collect',
      );
      expect(s.currentTargetToyId, original);
      expect(s.shouldShowTargetOverlay, isTrue);
    });

    test('lone toy lost (no toy-anchors) auto-collects (+1) and the clean area '
        'completes — the base-case first victory', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // single toy at x≈0.15, no toy-anchors

      // The child lifts the one toy; the camera now sees only a chair (raw
      // context, not a validated toy). This is the lone-toy base case: with no
      // toy-anchors the anchor-based scene check can only ever say
      // "insufficient", so the user-approved fallback confirms the pickup, and
      // the clean, seen area then auto-completes the mission.
      feed(ctrl, [_chair(x: 0.62)], 40);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1, reason: 'lone toy pickup is counted');
      expect(s.missionStatus, CleanupMissionStatus.completed);
      expect(s.shouldShowTargetOverlay, isFalse);
    });
  });

  group('hard target lock (the locked toy is never stolen)', () {
    test('a nearer, HIGHER-confidence toy never steals the locked target while '
        'it is still in view', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // Lock onto an off-center toy_001.
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.05)], 34);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;
      expect(original, isNotNull);

      // A dead-center, MAX-confidence toy_002 shows up next to it. By the
      // scorer's own rules it would outscore toy_001 — but the hard lock means
      // a toy that is merely "better" never re-points the highlight.
      feed(
        ctrl,
        [
          _teddyBear(classIndex: 1, x: 0.05),
          _teddyBear(classIndex: 2, x: 0.35, confidence: 0.99),
        ],
        12,
      );
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.currentTargetToyId,
        original,
        reason: 'a better toy appearing must not switch the locked target',
      );
      expect(s.collectedToyCount, 0);
    });

    test('only AFTER the locked toy is gone past the deadline does a pan '
        're-lock the visible toy (old stays pending, never counted)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 34);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;
      expect(original, isNotNull);
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 3);

      // Pan to a DIFFERENT toy briefly (under the re-scan deadline): the lock
      // holds — toy_001 is still the target even though it is off-screen.
      feed(ctrl, [_teddyBear(classIndex: 2, x: 0.70)], 10);
      expect(
        c.read(toyCleanupControllerProvider).currentTargetToyId,
        original,
        reason: 'a brief loss does not release the lock',
      );

      // Keep panned past the deadline: now the lost toy is invalidated by the
      // camera move and the one-pass re-scan locks the toy in view instead.
      feed(ctrl, [_teddyBear(classIndex: 2, x: 0.70)], 24);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.currentTargetToyId,
        isNot(original),
        reason: 'after the lock is truly gone, re-lock the visible toy',
      );
      expect(
        s.collectedToyCount,
        0,
        reason: 'a camera pan is never read as a pickup',
      );
      expect(s.knownToyCount, 2, reason: 'old kept pending + new toy added');
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('panning back to the first toy recovers its id (no duplicate)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 34);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 3);

      // Pan to toy_002 past the deadline → re-lock toy_002.
      feed(ctrl, [_teddyBear(classIndex: 2, x: 0.70)], 30);
      expect(
        c.read(toyCleanupControllerProvider).currentTargetToyId,
        isNot(original),
      );

      // …then pan back to the original toy, again past the deadline.
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 30);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.currentTargetToyId,
        original,
        reason: 'the first toy keeps its stable id',
      );
      expect(s.knownToyCount, 2, reason: 'no duplicate toy was created');
      expect(s.collectedToyCount, 0);
    });
  });

  group('collect → advance → rescan → ask → complete', () {
    test('collecting re-scans, then guides the next remaining toy', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 2);
      final first = c.read(toyCleanupControllerProvider).currentTargetToyId;

      // Pickup re-analyzes the scene instead of snapping to a stale snapshot.
      ctrl.collectCurrentToy();
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.cleanAreaVerification,
      );

      // The sweep settles on the toy that is still pending — the OTHER toy from
      // the initial scan (the one the scorer did not lock first), still in view.
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.15)], 24);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.currentTargetToyId, isNotNull);
      expect(s.currentTargetToyId, isNot(first));
    });

    test('three toys are guided one at a time, never repeating a target', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // Three clearly-separated toys (so neither tracking nor the dedup guard
      // confuses them).
      // Positions chosen so every 0.3-wide box stays in-frame (x + 0.3 ≤ 1.0)
      // yet centers are far enough apart that tracking/dedup never confuses
      // them (≈0.32 apart).
      List<YOLOResult> threeToys() => [
            _teddyBear(classIndex: 1, x: 0.05),
            _teddyBear(classIndex: 2, x: 0.38),
            _teddyBear(classIndex: 3, x: 0.70),
          ];
      feed(ctrl, threeToys(), 34);
      expect(c.read(toyCleanupControllerProvider).knownToyCount, 3);

      final seenTargets = <int>{};
      for (var i = 0; i < 3; i++) {
        final s = c.read(toyCleanupControllerProvider);
        expect(
          s.missionStatus.expectsCurrentTarget,
          isTrue,
          reason: 'toy ${i + 1} should be presented as a target',
        );
        final target = s.currentTargetToyId;
        expect(target, isNotNull);
        expect(
          seenTargets.contains(target),
          isFalse,
          reason: 'a collected/seen toy must never be selected again',
        );
        seenTargets.add(target!);
        ctrl.collectCurrentToy(); // → rescanning
        feed(ctrl, threeToys(), 24); // remaining toys still in view
      }
      final s = c.read(toyCleanupControllerProvider);
      expect(seenTargets.length, 3); // three DISTINCT targets, no repeats
      expect(s.collectedToyCount, 3);
    });

    test('after the last toy it verifies the area (does not complete yet)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy();
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus,
        CleanupMissionStatus.cleanAreaVerification,
        reason: 'Out of known toys → verify the floor, never instant-complete.',
      );
    });

    test('a COLLECTED toy still in frame does NOT block completion (the "3/3 '
        'never finishes" bug)', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // toy at x≈0.15
      ctrl.collectCurrentToy(); // collected; the SAME toy lingers in view
      // The picked-up toy stays on screen (held up / in a basket). It must NOT
      // keep the mission alive — there is nothing left to collect → finish.
      feed(ctrl, [_teddyBear(x: 0.15)], 30);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(
        s.missionStatus,
        CleanupMissionStatus.completed,
        reason: 'an already-collected toy in frame must not block completion',
      );
    });

    test('a blank/covered view does NOT complete — it keeps searching', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → cleanAreaVerification

      // The camera sees NOTHING (covered / pointed at a blank wall): the robot
      // is "not sure", so it must NEVER auto-complete on a blank view. It keeps
      // sweeping automatically (no button prompt) until it sees the area.
      feed(ctrl, const [], 24);

      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(s.missionStatus.isScanningPhase, isTrue);
      expect(s.debugSnapshot!.completedAllowed, isFalse);
    });

    test('clean sweep completes when the area is seen and no toys remain', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      // The camera SEES the area (furniture / real context) and finds no toys
      // → the visible area is clean and stable → auto-complete.
      feed(ctrl, [_chair()], 24);

      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        CleanupMissionStatus.completed,
        reason: 'saw the area with no toys → complete (baseline is irrelevant)',
      );
      expect(s.debugSnapshot!.completedAllowed, isTrue);
      expect(s.debugSnapshot!.guardReason, 'cleanAreaVerified');
    });

    test('a different UNCOLLECTED toy still visible keeps the mission going', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // collected toy at x≈0.15
      ctrl.collectCurrentToy(); // → clean-area search
      // A DIFFERENT toy (far from the collected one) is on the floor → there is
      // still something to collect, so the mission must not finish; it guides
      // to that toy instead.
      feed(ctrl, [_teddyBear(classIndex: 9, x: 0.7)], 24);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        isNot(CleanupMissionStatus.completed),
        reason: 'never finish while a toy still needs collecting',
      );
      expect(s.currentTargetToyId, isNotNull);
    });

    test('re-scan that sees the clean area (no toys) completes automatically',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      feed(ctrl, [_chair()], 24); // sees the area (furniture), no toys left
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.completed);
      expect(s.collectedToyCount, 1);
    });

    test('re-scan finds MORE toys → mission continues', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → rescanning
      // A new toy (different position) appears during the re-scan.
      feed(ctrl, [_teddyBear(classIndex: 9, x: 0.7)], 24);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.currentTargetToyId, isNotNull);
    });
  });

  group('manual fallback (model finds nothing)', () {
    test('no toys after retries → waitingForChildTap → tap → active', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      feed(ctrl, const [], 140); // exhaust the scan attempts (4 × 30 + margin)
      var s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.waitingForChildTap);

      // Automatic-first: "Buscar otra vez" re-scans with YOLO. If toys now
      // appear, the mission goes active WITHOUT any tapping.
      ctrl.restartScan();
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.scanning,
      );
      feed(ctrl, [_teddyBear(x: 0.4)], 34);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.active,
      );

      // Re-exhaust to get back to the fallback, then use the tap last resort.
      // Free/record mode so the single tapped pickup can auto-finish on a clean
      // area (a fixed-goal challenge would correctly refuse to complete at 1).
      ctrl.resetMission();
      ctrl.markModelReady();
      ctrl.startMission(goal: MissionGoal.record);
      feed(ctrl, const [], 140);
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.waitingForChildTap,
      );
      ctrl.addChildTapToy(0.5, 0.5);
      s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.active);
      expect(s.currentTargetToyId, isNotNull);
      expect(s.knownToyCount, 1);

      ctrl.collectCurrentToy(); // → clean-area search (no more known)
      feed(ctrl, [_chair()], 30); // sees the clean area → auto-finishes itself
      s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.completed);
      expect(s.collectedToyCount, 1);
    });

    test('a blank view never dead-ends: the mission keeps searching itself', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → clean-area search
      feed(ctrl, const [], 48); // a long blank view (camera covered/away)
      final s = c.read(toyCleanupControllerProvider);
      // The automatic flow never gets stuck in a button prompt and never
      // completes on a blank view — it just keeps sweeping for the next toy.
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
      expect(s.missionStatus.isScanningPhase, isTrue);
    });
  });

  group('verification metadata (persisted for the Parents view)', () {
    test('auto-complete via the clean-area sweep records visuallyVerified', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // toy at x≈0.15
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      feed(ctrl, [_chair()], 24); // sees the clean area → auto-completes
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.completed,
      );

      final saved = c.read(missionHistoryProvider);
      expect(saved, hasLength(1));
      expect(
        saved.first.visuallyVerified,
        isTrue,
        reason: 'automatic completion comes from a clean-area sweep',
      );
      // The routine "Listo, ya lo guardé" button is the happy path, not an
      // assist, and no target was ever lost → a clean, automatic run.
      expect(saved.first.usedManualHelp, isFalse);
      expect(saved.first.hadUncertainty, isFalse);
    });

    test('a child-tap fallback records usedManualHelp', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission(goal: MissionGoal.record); // free mode (completion test)
      feed(ctrl, const [], 140); // exhaust scan attempts → waitingForChildTap
      ctrl.addChildTapToy(0.5, 0.5); // the manual assist
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      feed(ctrl, [_chair()], 24); // sees the clean area → auto-completes
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.completed,
      );

      final saved = c.read(missionHistoryProvider);
      expect(saved, hasLength(1));
      expect(saved.first.usedManualHelp, isTrue);
    });
  });

  group('mission contract — count only verified pickups, never lose a toy', () {
    test('lone toy lost then a clean seen area confirms it (+1) and completes',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // single toy, no anchors
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 0);
      // The toy is gone; the camera keeps SEEING the area (furniture), no toy
      // in view. A lone-toy loss cannot be confirmed on a single frame (no
      // anchors) so it becomes a PENDING verification; the clean-area window
      // then confirms the pickup — the toy is counted (+1) and the mission
      // completes. It must NEVER complete with the toy left uncounted.
      feed(ctrl, [_chair()], 60);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.collectedToyCount,
        1,
        reason: 'the pending toy is counted when the clean area is verified',
      );
      expect(
        s.missionStatus,
        CleanupMissionStatus.completed,
        reason: 'never complete with an uncounted toy',
      );
    });

    test('a second visible toy blocks completion after collecting the first',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 2);
      ctrl.collectCurrentToy(); // → cleanAreaVerification, collected = 1
      // The OTHER toy is still on screen (a green box) during the sweep → the
      // mission must keep going (select it), never complete with a toy visible.
      feed(
        ctrl,
        [
          _teddyBear(classIndex: 1, x: 0.15),
          _teddyBear(classIndex: 2, x: 0.6),
        ],
        24,
      );
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        isNot(CleanupMissionStatus.completed),
        reason: 'a visible toy / green box must block completion',
      );
      expect(s.collectedToyCount, 1);
      expect(
        s.currentTargetToyId,
        isNotNull,
        reason: 'the remaining visible toy becomes the next target',
      );
    });
  });

  group('counting concept (collected score, baseline is diagnostic only)', () {
    test('mission starts at collectedToyCount = 0 and detecting does not add',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      expect(c.read(toyCleanupControllerProvider).collectedToyCount, 0);
      // Detecting + locking a toy must NOT increment the score — only a
      // verified pickup does.
      feed(ctrl, [_teddyBear()], 34);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.knownToyCount, 1);
      expect(s.currentTargetToyId, isNotNull);
      expect(
        s.collectedToyCount,
        0,
        reason: 'just detecting a toy must not add to the collected score',
      );
    });

    test('an over-counted baseline does NOT block completion', () {
      final c = container();
      addTearDown(c.dispose);
      // The initial scan sees TWO toys (baseline = 2).
      final ctrl = activeWith(c, n: 2);
      expect(c.read(toyCleanupControllerProvider).knownToyCount, 2);

      // The child collects the first toy...
      ctrl.collectCurrentToy(); // → cleanAreaVerification, collected = 1

      // ...but from now on the camera only ever sees the clean area (furniture).
      // The SECOND baseline toy is off-frame / was grouped / a double-count.
      // The mission must STILL complete: the baseline is diagnostic only and
      // never keeps the mission alive against what the camera actually sees.
      feed(ctrl, [_chair()], 24);

      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        CleanupMissionStatus.completed,
        reason: 'baseline=2 but the visible area is clean → complete',
      );
      expect(
        s.collectedToyCount,
        1,
        reason: 'the score is how many were collected, not the baseline',
      );
    });
  });

  group('completion rules / reset', () {
    test('a mission NEVER completes just because toys left the frame', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      // Toy leaves; lots of empty frames. We may re-scan and ask, but we
      // must never reach completed without the child confirming.
      feed(ctrl, const [], 60);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));
    });

    test('resetMission wipes back to idle', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 2);
      ctrl.resetMission();
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.idle);
      expect(s.knownToyCount, 0);
      expect(s.collectedToyCount, 0);
      expect(s.currentTargetToyId, isNull);
    });
  });
}
