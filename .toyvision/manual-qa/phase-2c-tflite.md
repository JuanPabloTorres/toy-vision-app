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

Phase 2c.0 is structurally complete (analyze clean, all tests pass, debug APK
builds). Real model inference is **not** enabled — it requires a trained model,
the full-color YUV→RGB preprocessing path (2c.1), and on-device validation.
