# Real-Time Detection Flow — ToyVision Real-Time

## Pipeline

```text
Camera frame
  ↓
FrameProcessingService      (throttle, skip-if-busy)
  ↓
ToyDetector                 (mock | ML Kit on-device | local vision server) → RawDetection list
  ↓
ToyDetectionRules           (category + confidence + bbox validation)
  ↓
ToyTrackingEngine           (IoU match, identity, missing-frame handling)
  ↓
ToyCountingService          (stability + duplicate prevention → count)
  ↓
CandidateReviewService      (manual Toy / Not-Toy confirmation, optional category)
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
  One of three implementations is selected at runtime via `ToyDetectorMode`:
  `MockToyDetector` (deterministic / demo), `MlKitObjectDetector` (Google ML Kit
  on-device, Object Assist), or `RemoteVisionDetector` (HTTP client → local Python
  vision server in `tools/vision_server/`). Non-mock primaries are wrapped in
  `FallbackToyDetector` so a failed init or runtime error degrades to the mock.
- **ToyDetectionRules** — filters raw detections against `ToyCategoryRegistry` and
  thresholds; produces validated candidate detections.
- **ToyTrackingEngine** — assigns/maintains identity across frames using IoU, handles
  brief disappearances up to `maximumMissingFrames`.
- **ToyCountingService** — promotes a tracked toy to "counted" once it is stable for
  `minimumStableFrames`; sets `hasBeenCounted`.
- **CandidateReviewService** — collects tracked toys as review candidates with status
  `pending | confirmed | ignored` and an optional user-assigned category. UI surfaces
  this via the `ReviewPanel` modal and the `CandidateReviewSummaryChip`. Confirmation is
  manual; nothing is auto-confirmed from detector output.
- **LiveDetectionState** — immutable view model: current boxes, total count, per-category
  summary, detector mode + fallback state, review summary.

## Performance rules

- Do not run inference on every frame by default — process selected frames only.
- Skip frames while inference is already running; **prevent concurrent inference**.
- The only network call permitted inside the live loop is the user-opt-in POST to the
  local vision server at the user-configured `baseUrl`. There is no other backend, no
  analytics call, and no third-party endpoint.
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
