# Real-Time Detection Flow — ToyVision Real-Time

## Pipeline

```text
Camera frame
  ↓
FrameProcessingService      (throttle, skip-if-busy)
  ↓
ToyDetector                 (mock now, TFLite later) → RawDetection list
  ↓
ToyDetectionRules           (category + confidence + bbox validation)
  ↓
ToyTrackingEngine           (IoU match, identity, missing-frame handling)
  ↓
ToyCountingService          (stability + duplicate prevention → count)
  ↓
LiveDetectionState          (immutable snapshot)
  ↓
UI rendering                (preview + overlay + counters)
```

Each arrow is a one-way handoff. No stage reaches backward; the UI consumes only
`LiveDetectionState`.

## Stage contracts

- **FrameProcessingService** — decides which frames to process; drops frames while
  inference is in flight; never blocks the camera preview.
- **ToyDetector** — returns raw detections only (`label`, `confidence`, `boundingBox`).
- **ToyDetectionRules** — filters raw detections against `ToyCategoryRegistry` and
  thresholds; produces validated candidate detections.
- **ToyTrackingEngine** — assigns/maintains identity across frames using IoU, handles
  brief disappearances up to `maximumMissingFrames`.
- **ToyCountingService** — promotes a tracked toy to "counted" once it is stable for
  `minimumStableFrames`; sets `hasBeenCounted`.
- **LiveDetectionState** — immutable view model: current boxes, total count, per-category
  summary, model status.

## Performance rules

- Do not run inference on every frame by default — process selected frames only.
- Skip frames while inference is already running; **prevent concurrent inference**.
- Do not call the backend inside the live detection loop.
- Keep the overlay lightweight — no heavy work in `paint()`.
- Dispose camera resources correctly on screen exit / app pause.
- Target inference rate: `targetInferenceFps` (5–10), defined in
  `RealtimeDetectionConfig`.

## Failure handling

- Detector failure → emit a `LiveDetectionState` with a model-error status; UI shows
  `model_loading_view` / error state, never a crash.
- Camera permission denied → `camera_permission_view`; no frames requested.
- No toys visible → `empty_detection_hint`; count stays at zero.

Guardrail: [skills/preserve-realtime-performance.md](skills/preserve-realtime-performance.md).
