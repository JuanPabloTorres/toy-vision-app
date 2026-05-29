# Manual QA / Enablement — Phase 2c TFLite

Phase 2c.0 adds the TFLite runtime foundation. The mock detector remains the
default; no model file is committed. This doc explains how to enable and verify
the TFLite path once a model exists.

## Why the mock is still the default

The proven mock pipeline keeps the app fully functional and testable while the
model/runtime are brought up. Switching the default to TFLite happens only after
on-device validation with a real model.

## How to enable TFLite mode manually

1. Add the model at `assets/models/toy_detector.tflite` (see
   `assets/models/README.md` for the exact input/output contract and class order).
2. Override the mode provider (e.g. in a dev build or a `ProviderScope` override):
   ```dart
   toyDetectorModeProvider.overrideWithValue(ToyDetectorMode.tfliteWithFallback)
   ```
3. Run on a device. If the model is valid it becomes active; otherwise the app
   falls back to the mock (`FallbackToyDetector.usingFallback == true`).

## What to verify once a model is present (on device)

| # | Check | Expected | Status |
|---|-------|----------|--------|
| 1 | App launches in tflite mode | No crash | Pending human verification |
| 2 | Valid model loads | TFLite active (not fallback) | Pending human verification |
| 3 | Missing/invalid model | Falls back to mock, app still works | Pending human verification |
| 4 | Mismatched tensor shapes | Falls back to mock | Pending human verification |
| 5 | Live detections | Boxes track real objects | Pending human verification |
| 6 | Person still ignored | Business layer filters it | Pending human verification |
| 7 | Counter stable | No runaway counting | Pending human verification |
| 8 | Performance | Responsive at target FPS | Pending human verification |
| 9 | No frames/video saved or uploaded | Confirmed | Pending human verification |

## Status

Phase 2c.1 is structurally complete (analyze clean, all tests pass, debug APK
builds). Real model inference is **not** enabled — it still requires a trained
model, on-device orientation validation, and threshold tuning.

## Camera preprocessing (Phase 2c.1)

Full-color conversion is implemented and unit-tested
(`image_format_converter.dart`):

- **Android YUV420** → RGB (BT.601, stride-aware, planar/semi-planar).
- **iOS BGRA8888** → RGB (channel reorder).
- Unsupported formats / short planes fail safely → frame dropped (non-fatal).
- **Rotation/orientation is NOT applied** — the buffer is in sensor orientation.
  Must be validated on device (Phase 2c.2); a model trained on upright images may
  need rotation first.

### On-device items still pending human verification

| # | Check | Status |
|---|-------|--------|
| A | YUV420 conversion correct on a real Android camera | Pending |
| B | BGRA8888 conversion correct on a real iOS camera | Pending |
| C | Orientation correct (or rotation added in 2c.2) | Pending |
| D | Preprocessing keeps the loop responsive at target FPS | Pending |

## Geometry / overlay alignment (Phase 2c.2)

Orientation and coordinate-mapping helpers exist in `lib/detection/geometry/` and
are unit-tested, but are **not wired into production** — the overlay still draws
normalized boxes directly over a `BoxFit.cover` preview, and rotation defaults to
none. Real alignment must be confirmed on a device:

| # | Check | Status |
|---|-------|--------|
| E | `FrameOrientation.quarterTurns` matches the real device/sensor | Pending |
| F | Rotated boxes line up with detected objects | Pending |
| G | `PreviewCoordinateMapper` cover mapping aligns box to cropped preview | Pending |
| H | Front-camera mirroring (if used) is correct | Pending |
