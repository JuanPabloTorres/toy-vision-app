# Architecture Principles

## One-way production flow

```text
Camera / YOLO
→ YoloDetectionMapper
→ ToyDetectionRules
→ ToyTrackingEngine
→ RoomSceneStabilityService + RoomSnapshotBuilder
→ RoomSnapshot
→ CleanupProgressEngine
→ KidGameController / KidGamePhase
→ ToyBotRewardService
→ KidGameState
→ Kid UI
```

`KidGameController` is the only cleanup-session orchestrator. `KidGamePhase` is
the only primary lifecycle. No parallel object-by-object mission system is
permitted.

## Ownership

- Detection maps model output; it does not decide game completion.
- Tracking maintains physical identity; it does not award progress.
- Snapshot builders qualify temporal evidence; no single frame is product truth.
- Progress compares the immutable initial snapshot with the current snapshot.
- Reward logic owns monotonic visible energy and idempotent reward events.
- The controller owns transitions, final-check evidence, and confirmation.
- UI renders `KidGameState` and never interprets detector output.
- Storage persists only privacy-safe session estimates at lifecycle boundaries.

Thresholds belong in `RealtimeDetectionConfig`. Lower layers never depend on UI.
