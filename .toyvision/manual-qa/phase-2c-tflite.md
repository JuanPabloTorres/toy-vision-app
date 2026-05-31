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

## Phase 2d real-device pass for the MOCK pipeline — 2026-05-30

Context: validated on a Samsung Galaxy S25 (Android 16, serial RFCY2244PCJ).
The real camera plumbing from Phase 2a is now visually confirmed end to end on
hardware, but TFLite is still **not** enabled — the mock detector remains the
default and no `.tflite` model is committed.

### What this validates

- A real `CameraImage` stream reaches our pipeline (not just unit-test fakes).
- Clean camera open → active → close lifecycle in logcat
  (`CAMERA_STATE_OPENING` → `OPEN` → `ACTIVE` → `CLOSING` → `IDLE` → `CLOSED`,
  no `onError`, no `FATAL`, no `Exception`).
- Mock detections drive the overlay, the "Toys counted" counter, and the
  "By category" panel correctly; the count is stable (duplicate prevention
  works end to end).
- People are ignored end to end: the TV in the preview shows two people, and
  neither is labeled or boxed — the business-layer ignore rules hold on real
  hardware, not only in tests.
- The privacy notice is rendered exactly as written:
  "Toys only. Runs on your device. No video saved or uploaded. People are
  ignored."

### What this does NOT validate

- Real YUV420 conversion correctness against a trained model (still pending,
  because no model exists yet).
- BGRA8888 on iOS (still pending — no iOS device was used).
- Orientation / rotation under a real model (still pending — the geometry
  mappers in `lib/detection/geometry/` exist and are unit-tested but are not
  wired; the preview is in sensor orientation).
- Preview-to-overlay pixel alignment (`PreviewCoordinateMapper` is not wired;
  the overlay paints with `Positioned.fill` over a `BoxFit.cover` preview, so
  box placement is approximate).
- On-device latency / FPS with real inference.
- Pause / resume / reset and background ↔ foreground interactive flows — the
  user returned the QA template with the `[PASO/FALLO]` and `[SI/NO]`
  placeholders unfilled, so these remain pending human verification.

### Status of existing geometry items

Items **E–H** above (sensor orientation, rotated boxes, `PreviewCoordinateMapper`
cover mapping, front-camera mirroring) remain **Pending**. Phase 2d did not
change their state; they still require a real-model on-device pass.

### Final decision

- Phase 2d: **passed** for the mock real-device pipeline.
- **Approved** to proceed to the dataset / model pipeline (see
  [`../model-training/README.md`](../model-training/README.md)).
- **Not approved** to enable TFLite by default yet.
- On-device validation for real inference (this document's existing checklist,
  rows 1–9 and A–H) remains pending until a trained model exists.
