# Technology Stack — ToyVision Real-Time

Use this stack unless there is a **strong, documented** reason to change it. Changes are
owned by the Solution Architect Agent and must be recorded in the change log at the
bottom of this file with rationale and date.

## Mobile app (Flutter)

- **Flutter** + **Dart** (UI + app runtime)
- **Material 3** (design system baseline)
- **flutter_riverpod** (state management — single, no Provider mixing)
- **camera** package (camera access + frame stream)
- **google_mlkit_object_detection** (on-device coarse object detection — "Object Assist")
- **http** (LAN client for the local Python vision server)
- **image** (pure-Dart JPEG encoder for camera frames sent to the vision server)
- **CustomPainter** (detection overlay rendering)
- Local history is currently in-memory (`InMemoryScanHistoryRepository`). A persistent
  backend (SQLite or Hive) is allowed when the feature requires it; pick **one** library
  if/when that day comes.

## AI / computer vision

Detection is split into three runtime modes, all behind the `ToyDetector` interface:

- **Mock detector** (`MockToyDetector`) — deterministic, demo, default for development
  and tests.
- **On-device Object Assist** — `MlKitObjectDetector` (Google ML Kit). Treated as a hint
  the user confirms via the manual review panel; runs fully on-device.
- **Local open-vocabulary vision server** — `RemoteVisionDetector` (Dart HTTP client) ↔
  `tools/vision_server/` (Python FastAPI server, run on the user's own PC over the LAN).
  Schemas in `lib/detection/detectors/remote/remote_vision_schemas.dart` mirror
  `tools/vision_server/schemas.py` 1:1.

Non-mock primaries are wrapped in `FallbackToyDetector` so init or runtime errors degrade
gracefully to the mock detector.

### Out of scope (deprecated)

- **No custom dataset training.** The EfficientDet / MediaPipe Model Maker / Colab path
  has been archived (see [archive/model-training/](archive/model-training/)).
- **No bundled `tflite_flutter` runtime.** The `tflite_flutter` dependency and
  `assets/models/*.tflite` were removed in Phase 5.0.
- **No COCO SSD baseline.** Generic-baseline evaluation is archived.

The taxonomy and privacy rules from that era are preserved as living reference docs in
[reference/](reference/).

## Backend (optional, future)

The real-time detection loop must stay **local-first**. The only network call permitted
inside the live loop is the user-opt-in POST to the local vision server at the
user-configured `baseUrl`. There is no cloud endpoint, no analytics, no third-party call.

If a future feature (account sync, model registry, scan-history backup, feedback
collection) needs a real backend, it must sit *outside* the live loop. Stack candidates
when that day arrives: .NET 8 Web API, PostgreSQL, EF Core, cloud storage.

## Important stack rules

- The real-time detection loop must run locally and must not depend on third-party
  network latency.
- Pick **one** state management library and use it consistently. (Today: Riverpod.)
- Pick **one** local persistence library and use it consistently when persistence lands.
- No additional dependency may be added without justification recorded by the Solution
  Architect Agent.

## Stack change log

| Date | Change | Rationale | Approved by |
|------|--------|-----------|-------------|
| 2026-05-28 | Initial stack defined | Project bootstrap | Solution Architect Agent |
| 2026-05-28 | State management = **Riverpod** (`flutter_riverpod`); Provider not used | Single, testable, compile-safe dependency graph for the live detection controller; keeps business services pure and injectable | Solution Architect Agent |
| 2026-05-28 | Phase 1 excludes `tflite_flutter` and the `camera` plugin is present but not yet wired (placeholder preview) | Mock-first rule: prove camera shell, tracking, and counting before real inference | Solution Architect Agent |
| 2026-05-29 | `tflite_flutter` added behind the `ToyModelRuntime` seam (Phase 2c.0) | Move toward real on-device inference once camera shell and tracking are stable | Solution Architect Agent |
| 2026-05-29 | Replace `tflite_flutter` with `google_mlkit_object_detection` (Phase 3.6) | Camera-stream input proved brittle in the custom TFLite pipeline (uint8 reshape quirks, manual YUV→RGB, no built-in orientation); ML Kit is on-device, handles orientation/format, and accepts a custom TFLite classifier later via `LocalModel.fromAsset()` if needed | Solution Architect Agent |
| 2026-06-01 | Phase 5.0 — local Python vision server + `RemoteVisionDetector` HTTP client become the strategic AI path; ML Kit reframed as "Object Assist"; custom dataset training, EfficientDet training, COCO SSD baseline, and bundled `tflite_flutter` runtime are archived as deprecated | Custom training was too costly for the project's scope; an open-vocabulary local server on the user's own PC delivers usable detection without shipping a model | Solution Architect Agent |
