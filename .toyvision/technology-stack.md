# Technology Stack — ToyVision Real-Time

Use this stack unless there is a **strong, documented** reason to change it. Changes are
owned by the Solution Architect Agent and must be recorded here with rationale and date.

## Mobile app

- **Flutter** (UI + app runtime)
- **Dart** (language)
- **Material 3** (design system baseline)
- **camera** package (camera access + frame stream)
- **tflite_flutter** (on-device inference, later phase)
- **CustomPainter** (detection overlay rendering)
- **Riverpod or Provider** (state management — pick one, do not mix)
- **SQLite or Hive** (optional local history for saved summaries)

## AI / computer vision

- YOLO-based object detection model.
- Export target: **TensorFlow Lite**.
- Initial real-time inference: **local device execution**.
- Initial development phase: **mock detector** (`MockToyDetector`).
- Future optional targets: ONNX, CoreML.

## Backend (optional for MVP)

Backend is **optional** for the MVP. **The real-time detection loop must never depend on
backend calls or network latency.**

Future backend may use:

- .NET 8 Web API
- PostgreSQL
- Entity Framework Core
- Cloud storage for optional dataset/model management

Future backend may support: account sync, model version configuration, dataset
management, optional scan-history backup, feedback/correction collection, and training
pipeline metadata. None of these may enter the live detection path.

## Important stack rules

- The real-time detection loop must run **locally** and must not depend on network
  latency.
- Pick **one** state management library and use it consistently.
- Pick **one** local storage library and use it consistently.
- No additional dependency may be added without justification recorded by the Solution
  Architect Agent.

## Stack change log

| Date | Change | Rationale | Approved by |
|------|--------|-----------|-------------|
| 2026-05-28 | Initial stack defined | Project bootstrap | Solution Architect Agent |
| 2026-05-28 | State management = **Riverpod** (`flutter_riverpod`); Provider not used | Single, testable, compile-safe dependency graph for the live detection controller; keeps business services pure and injectable | Solution Architect Agent |
| 2026-05-28 | Phase 1 excludes `tflite_flutter` and the `camera` plugin is present but not yet wired (placeholder preview) | Mock-first rule: prove camera shell, tracking, and counting before real inference | Solution Architect Agent |
