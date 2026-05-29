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
