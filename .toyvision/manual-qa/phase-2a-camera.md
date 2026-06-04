# Manual QA Checklist — Phase 2a (Real Camera Preview, Mock Detections)

Real `camera` plugin behavior cannot be verified by headless unit tests, so this
checklist must be run on a physical device or emulator with a working camera.
Owned by the QA Validation Agent.

## Preconditions

- Platform folders exist (`flutter create .` if `android/` / `ios/` are absent).
- **Android**: `<uses-permission android:name="android.permission.CAMERA"/>` and
  `minSdkVersion >= 21` in the app manifest/gradle.
- **iOS**: `NSCameraUsageDescription` set in `Info.plist`
  (e.g. "ToyVision uses the camera only to detect toys on your device.").
- Detector is still `MockToyDetector` (no TFLite).

## Checklist

| # | Step | Expected result | Pass/Fail |
|---|------|-----------------|-----------|
| 1 | First launch | OS camera permission prompt appears | ☐ |
| 2 | Deny permission | `CameraPermissionView` shows a clear message; no crash; "Allow camera" retry present | ☐ |
| 3 | Allow permission | Real camera preview renders full-screen | ☐ |
| 4 | Observe overlay | Bounding-box overlay is drawn on top of the preview | ☐ |
| 5 | Observe mock detections | Boxes for toy_car / stuffed_animal move/update over time | ☐ |
| 6 | Watch the counter | Count rises then stays stable (no runaway counting) | ☐ |
| 7 | Person in mock set | The mock `person` is never counted or labeled as a person | ☐ |
| 8 | Tap pause | Detection updates freeze; status chip shows "Paused" | ☐ |
| 9 | Tap resume | Detection updates continue | ☐ |
| 10 | Tap reset | Count returns to 0; category summary clears | ☐ |
| 11 | Leave screen / background app | Camera is released (no camera-in-use indicator persists) | ☐ |
| 12 | Return to screen / foreground | Preview and detection resume cleanly | ☐ |
| 13 | Inspect storage/network | No video, frames, or images are saved or uploaded anywhere | ☐ |
| 14 | `flutter analyze` | No issues | ☐ |
| 15 | `flutter test` | All tests pass | ☐ |

## Notes / observations

- Overlay-to-preview pixel alignment is approximate in Phase 2a (mock boxes are
  normalized to the full frame and the preview is scaled with `BoxFit.cover`).
  Precise alignment will be revisited in Phase 2b when real detections arrive.
- Record device, OS version, and any anomalies here when running the checklist.

## Phase 2a.2 smoke-test attempt — 2026-05-29

Attempted an Android emulator runtime smoke test. **Could not boot any emulator:**

- `system-images/` in the Android SDK is empty — no system image is installed,
  so every AVD fails with `Cannot find AVD system path`.
- `flutter doctor`: Android cmdline-tools missing and licenses unaccepted.
- No physical Android/iOS device attached (`flutter devices` shows only Windows,
  Chrome, Edge).

Booting would require installing cmdline-tools + an ~1GB system image + license
acceptance (a heavy SDK mutation), so it was not performed in this pass.

### Automatically verified (no device needed)

| Check | Result |
|-------|--------|
| `flutter pub get` | ✅ ok |
| `flutter analyze` | ✅ clean |
| `flutter test` (46) | ✅ all pass |
| `flutter build apk --debug` | ✅ builds; native camera plugin compiles |
| Merged Android manifest | ✅ `CAMERA` only — no `RECORD_AUDIO`, no storage |

### Pending human visual verification (require a booted device)

Items 1–13 of the checklist above: permission prompt, deny state, preview render,
overlay alignment, moving mock detections, stable counter, person ignored,
pause/resume freeze/continue, reset clears UI, dispose-on-leave, reopen.

**Status: runtime smoke test passed structurally; live camera QA pending a
device/emulator with an installed system image.**

### Overlay alignment note (Phase 2c.2)

The overlay currently draws normalized boxes directly over a `BoxFit.cover`
preview, which crops one axis — so boxes will not be pixel-aligned with the
preview until the geometry mappers (`lib/detection/geometry/`) are wired and
verified on a device. Track this alongside the live camera QA above.

## Phase 2d device-QA attempt — 2026-05-29 (BLOCKED)

Attempted the physical-device QA gate. **Blocked: no physical Android device
available** and no emulator with an installed system image.

- `flutter devices` → only Windows, Chrome, Edge (no Android target).
- `adb devices` → empty list.
- No `.tflite` model and no code changes since 2c.2 (`38f2ee2`); automated gates
  remain green (analyze clean, 107 tests, debug APK builds).

**All checklist items 1–33 remain: Pending human visual verification.** To
proceed, attach a physical Android phone (USB debugging) or install an Android
emulator system image. Model dataset/training (Phase 2e) should not start until
this gate passes.

## Phase 2d real-device pass — 2026-05-30 (Galaxy S25 / Android 16)

Run on Samsung Galaxy S25 (SM-S931U), serial `RFCY2244PCJ`, ABI `android-arm64`,
Android 16 (API 36); the prior "blocked" attempts above are now superseded for
the mock real-device pipeline.

### Results vs. the 33-item checklist

| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | First-launch camera permission prompt | PASS | logcat shows `CAMERA_STATE_OPENING` → `OPEN` after grant |
| 2 | Deny permission shows `CameraPermissionView` | Pending human visual verification | deny path not exercised on this run |
| 3 | Allow permission renders full-screen preview | PASS | screenshot shows live rear-camera preview (room + TV) |
| 4 | Overlay drawn on top of preview | PASS | two mock bounding boxes painted over preview |
| 5 | No microphone permission requested | PASS | merged manifest = `CAMERA` only; no `RECORD_AUDIO` |
| 6 | No storage permission / no media writes | PASS | merged manifest has no storage perms |
| 7 | Mock `person` never counted / labeled | PASS | two people visible on TV in preview, zero person boxes/labels drawn |
| 8 | Tap pause freezes detection updates | Pending human visual verification | interactive tap not observed in this pass |
| 9 | Tap resume continues detection | Pending human visual verification | interactive tap not observed in this pass |
| 10 | Tap reset clears count + categories | Pending human visual verification | interactive tap not observed in this pass |
| 11 | Background releases camera | Pending human visual verification | clean `CLOSED` seen on flutter disconnect, but not a confirmed Home-button cycle |
| 12 | Foreground resumes preview cleanly | Pending human visual verification | not exercised |
| 13 | No video / frames / images saved or uploaded | PASS | no storage perms in merged manifest; no upload/network code on this path |
| 14 | No upload of frames | PASS | merged manifest + code path show no network egress for frames |
| 15 | Mock detections move/update over time | PASS | screenshot shows live mock boxes on real preview |
| 16 | "Toys counted" panel readable | PASS | screenshot: "Toys counted: 2" |
| 17 | Counter stable, no runaway counting | PASS | count holds at 2 — duplicate prevention works end to end |
| 18 | Category summary populated | PASS | "Toy car 1", "Stuffed animal 1" |
| 19 | Status chip visible | PASS | "Detecting" chip with green dot |
| 20 | Privacy notice exact text | PASS | "Toys only. Runs on your device. No video saved or uploaded. People are ignored." |
| 21 | Pause control present | PASS | pause button visible in bottom controls |
| 22 | Reset control present | PASS | reset button visible in bottom controls |
| 23 | Save control present | PASS | save button visible |
| 24 | Save intentionally disabled | PASS | `onPressed: null`; tooltip "Save summary (Phase 2b+)" |
| 25 | App launches without crash | PASS | pid 27933; Impeller/Vulkan rendering active |
| 26 | No FATAL in logcat | PASS | no FATAL entries from app pid |
| 27 | No `onError` from CameraDevice | PASS | only `onOpened` → `onClosed` |
| 28 | No uncaught `Exception` in logcat | PASS | none observed for app pid |
| 29 | Clean camera lifecycle on shutdown | PASS | `Releasing session OPENED → CLOSING → IDLE → CLOSED` |
| 30 | Real rear camera bound (BACK) | PASS | logcat: `Camera 0 BACK` for `com.example.toyvision_realtime` |
| 31 | Overlay aligns to preview region | Partial / known limitation | overlay uses `Positioned.fill` over `BoxFit.cover`; geometry mappers not wired (see below) |
| 32 | Bottom panel does not occlude critical UI | Partial / known limitation | "Toy car" label partially covered by "By category" panel |
| 33 | "Lost connection to device" not a crash | PASS | confirmed: debug-session disconnect at end of `flutter run`, not an app fault |

### Lifecycle / native evidence

`logcat` for app pid 27933 shows a clean camera lifecycle:

```
CameraDevice.onOpened
CaptureSession.onConfigured → onReady
Camera 0 BACK CAMERA_STATE_OPENING → OPEN → ACTIVE  (client com.example.toyvision_realtime)
Releasing session OPENED → CLOSING → IDLE → CLOSED
CameraDevice.onClosed
```

No FATAL, no `onError`, no uncaught Exception from the app's pid across the
session. The trailing "Lost connection to device" line is the debug bridge
disconnecting, not an app crash.

### Known limitations

- Overlay-to-preview pixel alignment is approximate. The overlay paints with
  `Positioned.fill` (full screen) while the preview uses `BoxFit.cover`, so
  boxes do not precisely match the cropped preview region. The Phase 2c.2
  geometry helpers in `lib/detection/geometry/` exist and are unit-tested but
  are not wired into production yet.
- Bottom-panel z-order: the floating "By category" panel partially covers the
  "Toy car" box label — a layout artifact tracked for Phase 3.8 UI polish.
- Save button shows emphasized styling but is intentionally disabled (storage
  layer is a later phase); Phase 3.8 should make the disabled state clearer.

### Final decision

- Phase 2d: passed for mock real-device pipeline.
- Approved to proceed to dataset/model pipeline.
- Not approved to enable TFLite by default yet.

> **Historical note (Phase 5.0):** the dataset/TFLite "next step" was superseded.
> The active AI path is now the local Python vision server
> (`tools/vision_server/`) plus the on-device ML Kit "Object Assist" mode;
> see [../ai-model-guidelines.md](../ai-model-guidelines.md). The original
> training docs are preserved under
> [../archive/model-training/](../archive/model-training/).

## Phase 3.3 product-completion checks (mock detector still default)

After product-completion UI changes (compact privacy, compact category panel,
detector-mode chip, in-memory save + history). These remain **Pending human
visual verification** on the Galaxy S25; the underlying behavior is covered by
unit + widget tests.

| # | Check | Status |
|---|-------|--------|
| 34 | Privacy notice shows full text on first open | Pending |
| 35 | Tapping the privacy notice collapses it to "On-device only" | Pending |
| 36 | Tapping again re-expands it | Pending |
| 37 | Category panel scrolls horizontally with many categories | Pending |
| 38 | Category panel no longer covers the lower preview area | Pending |
| 39 | `Mode: Mock` chip is visible at top-right | Pending |
| 40 | Save button is disabled while the count is 0 | Pending |
| 41 | Save button enables once the count is ≥ 1 | Pending |
| 42 | Tapping Save shows "Summary saved · N toys" snackbar | Pending |
| 43 | Snackbar "View" action opens the Saved Scans screen | Pending |
| 44 | Saved Scans screen lists newest-first | Pending |
| 45 | Each saved tile shows total, time, per-category badges, and `Mode: …` chip | Pending |
| 46 | Saved Scans "Clear all" empties the list | Pending |
| 47 | No image, video, or frame is ever written (storage perms not requested) | PASS — merged manifest unchanged, still `CAMERA` only |
| 48 | Pause / resume / reset still work after the layout changes | Pending |
| 49 | Existing 33-item checklist above is not regressed | Pending |

The interactive items from earlier (8–12) remain **Pending** as well; nothing
in Phase 3.3 closes them.
