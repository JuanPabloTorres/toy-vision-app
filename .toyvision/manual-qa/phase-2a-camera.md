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
