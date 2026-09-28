# Design Patterns

## Strategy and pipeline

`YoloDetectionMapper`, `ToyDetectionRules`, and `ToyTrackingEngine` are
replaceable lower-layer collaborators. They produce observations, not product
completion decisions.

## Temporal builder

`RoomSnapshotBuilder` owns temporal fusion and emits immutable snapshots with
an explicit quality result.

## Pure domain services

`CleanupProgressEngine` and `ToyBotRewardService` are deterministic services.
They do not know about Flutter widgets, camera lifecycle, or storage.

## Single orchestrator

`KidGameController` owns the session lifecycle and publishes immutable
`KidGameState`. UI callbacks request transitions; widgets do not derive them.

## Repository

History, active-session markers, and settings use Riverpod repositories.
Writes happen only at lifecycle boundaries, never inside the frame loop.

## Central configuration

All perception thresholds and game timings live in `RealtimeDetectionConfig`.
