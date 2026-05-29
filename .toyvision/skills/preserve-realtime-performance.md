# Skill: preserve-realtime-performance

## Purpose
Ensure frame processing never overloads the device or blocks the UI.

## When to use
Any time you touch the camera loop, frame processing, inference scheduling, or the
overlay.

## Required rules
- Process selected frames only; honor `targetInferenceFps`
  ([realtime-detection-flow.md](../realtime-detection-flow.md)).
- Skip frames while inference is running; prevent concurrent inference.
- Keep the overlay lightweight — no heavy work in `paint()`.
- Dispose camera resources on exit/pause.
- Never call the backend in the live loop.

## Forbidden patterns
- Inference on every frame.
- Overlapping/concurrent inference.
- Blocking the preview while processing.
- Network calls in the detection loop.
- Leaking camera controllers.

## Acceptance criteria
- Inference runs at the configured rate, one at a time.
- The preview stays responsive under load.
- Camera resources are released correctly.
- The live loop makes no network calls.
