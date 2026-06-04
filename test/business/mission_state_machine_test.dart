import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/mission/cleanup_mission_status.dart';
import 'package:toyvision_realtime/camera/controllers/toy_cleanup_controller.dart';
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
  ToyCleanupController activeWith(ProviderContainer c, {int n = 2}) {
    final ctrl = c.read(toyCleanupControllerProvider.notifier);
    ctrl.markModelReady();
    ctrl.startMission();
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
      feed(ctrl, const [], 30);
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
      // A few frames into the scan window (not enough to finish it).
      feed(ctrl, [_teddyBear(x: 0.3), _teddyBear(classIndex: 2, x: 0.7)], 6);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.scanning);
      expect(
        s.visibleToys,
        isNotEmpty,
        reason: 'The child must see boxes while the robot is scanning.',
      );
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

    test('a long loss auto-rescans — never freezes the box, never completes',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);

      // Lose the toy for longer than the rescan window (> targetRescanFrames).
      feed(ctrl, const [], 30);
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        anyOf(
          CleanupMissionStatus.rescanning,
          CleanupMissionStatus.askingIfMoreToys,
        ),
        reason: 'a long loss must re-scan, not keep a frozen target',
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

      feed(ctrl, [anchor()], 10); // lost, but under the auto-collect threshold
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

    test('lone toy, ambiguous loss → rare manual fallback "¿Lo recogiste?"',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // single toy at x≈0.15, no anchors
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;

      // The camera still sees context (a chair → scene valid) but there is no
      // valid TOY to switch to and no anchors to tell a pickup from a pan → ask.
      feed(ctrl, [_chair(x: 0.62)], 30);
      var s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.confirmingPickup);
      expect(s.collectedToyCount, 0);
      expect(s.shouldShowTargetOverlay, isFalse);

      ctrl.confirmPickupYes();
      s = c.read(toyCleanupControllerProvider);
      expect(s.collectedToyCount, 1);
      expect(s.currentTargetToyId, isNot(original));
    });
  });

  group('target switching (follow the child to another toy)', () {
    test('target lost + a NEW toy in view → switches, old stays pending', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = c.read(toyCleanupControllerProvider.notifier);
      ctrl.markModelReady();
      ctrl.startMission();
      // Only toy_001 in the initial scan.
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 34);
      final original = c.read(toyCleanupControllerProvider).currentTargetToyId;
      expect(original, isNotNull);
      expect(c.read(toyCleanupControllerProvider).knownToyCount, 1);
      // A few active frames (toy_001 is the target; no other anchors).
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 3);

      // Child pans to a DIFFERENT area: toy_001 leaves, toy_002 (new) appears.
      feed(ctrl, [_teddyBear(classIndex: 2, x: 0.70)], 14);

      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.currentTargetToyId,
        isNot(original),
        reason: 'the new visible toy becomes the target',
      );
      expect(
        s.collectedToyCount,
        0,
        reason: 'the old target is NOT collected, just pending',
      );
      expect(
        s.knownToyCount,
        2,
        reason: 'old kept pending + new toy added (no completion)',
      );
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

      // Switch to toy_002…
      feed(ctrl, [_teddyBear(classIndex: 2, x: 0.70)], 14);
      expect(
        c.read(toyCleanupControllerProvider).currentTargetToyId,
        isNot(original),
      );

      // …then pan back to the original toy.
      feed(ctrl, [_teddyBear(classIndex: 1, x: 0.12)], 14);
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

      // The sweep settles on the toy that is still pending — a different one.
      feed(ctrl, [_teddyBear(x: 0.6)], 24);
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
      // All three collected and the (collected) toys are still in view → the
      // clean-area sweep sees the area and auto-completes. No asking.
      expect(s.missionStatus, CleanupMissionStatus.completed);
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

    test('last toy + the area is actually seen → auto-completes (no asking)',
        () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1); // toy at x≈0.15
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      // The camera keeps seeing the area; nothing NEW (the toy is collected) →
      // verification passes and the mission completes on its own.
      feed(ctrl, [_teddyBear(x: 0.15)], 24);
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.completed);
      expect(s.collectedToyCount, 1);
    });

    test('manual finish is blocked while a toy is still visible', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → cleanAreaVerification
      feed(ctrl, const [], 24); // empty → no view → asks (fallback)
      expect(
        c.read(toyCleanupControllerProvider).missionStatus,
        CleanupMissionStatus.askingIfMoreToys,
      );

      // A toy is now in view again; the child taps "No, terminé".
      feed(ctrl, [_teddyBear(x: 0.3)], 1);
      ctrl.childDone();
      final s = c.read(toyCleanupControllerProvider);
      expect(
        s.missionStatus,
        isNot(CleanupMissionStatus.completed),
        reason: 'never finish with a toy still on the floor',
      );
    });

    test('re-scan finds nothing → asks "¿ves otro?" → child finishes', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → rescanning
      feed(ctrl, const [], 24); // empty re-scan window (20 frames + margin)
      var s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.askingIfMoreToys);
      expect(s.missionStatus, isNot(CleanupMissionStatus.completed));

      ctrl.childDone();
      s = c.read(toyCleanupControllerProvider);
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
      ctrl.resetMission();
      ctrl.markModelReady();
      ctrl.startMission();
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

      ctrl.collectCurrentToy(); // → rescanning (no more known)
      feed(ctrl, const [], 24);
      ctrl.childDone();
      s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.completed);
      expect(s.collectedToyCount, 1);
    });

    test('"Sí, veo otro" with empty re-scan ends at waitingForChildTap', () {
      final c = container();
      addTearDown(c.dispose);
      final ctrl = activeWith(c, n: 1);
      ctrl.collectCurrentToy(); // → rescanning
      feed(ctrl, const [], 24); // → askingIfMoreToys

      ctrl.childSeesAnotherToy(); // → rescanning (from ask)
      feed(ctrl, const [], 24); // nothing found
      final s = c.read(toyCleanupControllerProvider);
      expect(s.missionStatus, CleanupMissionStatus.waitingForChildTap);
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
