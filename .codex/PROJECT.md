# Project

## Purpose

Toy Vision is an offline-first Flutter game that helps a child pick up toys.
Computer vision is a quiet sensor. The child-facing loop is:

```text
SEE → FIND → PICK UP → SYSTEM REACTS → REWARD → CONTINUE
```

The shipped flow is `Home → Scan/Cleanup → Celebration`; Settings is separate
adult-facing functionality. Developer Vision Debug may display proposals,
candidates, tracks, and evidence, but Kid Mode must not become a CV dashboard.

## Runtime stack

- Flutter/Dart with Riverpod.
- `ultralytics_yolo` 0.4.3 and bundled
  `assets/models/cleanup_items.tflite` for on-device CameraX/TFLite proposals.
- Pixel analysis, open-set regions, perceptual descriptors, fusion, tracking,
  scene reasoning, and disappearance verification in Dart.
- SQLite for privacy-safe session, room, reward-ledger, streak, and achievement
  progress; SharedPreferences is limited to UI settings and one-time migration.
- Rive, Lottie, glTF, audio, and haptics driven from cleanup domain events.
- Android minimum API 24; Java 17; current release signing still uses debug
  keys and is not production distribution evidence.

## Production and diagnostic boundaries

Production code is under `lib/`. The normal camera path is hosted by
`presentation/cleanup/cleanup_screen.dart`, adapted in
`infrastructure/camera/yolo_streaming_frame_adapter.dart`, and processed by
`perception/perception_engine.dart`.

Diagnostics are:

- `DeveloperVisionOverlay` and `VisionDisplayMode.developer`;
- opt-in JSONL capture in `JsonlPerceptionEvidenceRecorder`;
- `tools/toyvision_certify.dart` and `tools/certification/**`;
- synthetic replay fixtures and performance tests;
- `.toyvision/archive/**`, which is non-production history.

Certification capture can retain pixels only when explicitly enabled. Normal
operation must not persist frames, embeddings, audio, or identities.

## Current release truth

Current status is `PARTIAL`, not commercial `PASS`:

- automated Flutter tests and desktop synthetic replay exist;
- physical Galaxy S25 validation is blocked/unrecorded;
- a representative, completely annotated real corpus is absent;
- Ultralytics AGPL/Enterprise licensing is unresolved for closed commercial
  distribution;
- the Android release build uses debug signing;
- the current perceptual embedding is an engineered visual descriptor, not a
  validated semantic toy embedding.
