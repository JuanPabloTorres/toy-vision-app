# Architecture

## Intended dependency direction

```text
Presentation → Application → Domain
       │              ↑
       └─ composition/adapters ─ Infrastructure

Camera/TFLite → Perception → RoomWorldModel → Application domain events
                                            → Presentation/feedback
```

Domain owns cleanup truth. Perception produces evidence and a world model, not
game rewards. Presentation renders application state and reacts to domain
events. Infrastructure implements device/plugin/persistence/audio boundaries.

## Observed owners

| Concern | Owner |
|---|---|
| App entry/routes/theme | `lib/main.dart`, `lib/app/**` |
| Cleanup orchestration/state | `lib/application/cleanup/**` |
| `ToyCollected`, `RoomCleanConfirmed`, `CleanupCompleted` decisions | `CleanupSessionService` |
| Domain entities/invariants | `lib/domain/**` |
| Frame pipeline/world-model creation | `HybridToyPerceptionEngine` |
| Proposal acceptance | `ToyCandidateFusion` |
| Identity/lifecycle | `ToyTracker`, `TrackAssociator` |
| Scene/missing proof | `SceneStabilityService`, `ToyRemovalVerifier` |
| Room discovery completion | `RoomDiscoverySession` |
| Final room-clean proof | `RoomCleanVerifier` |
| Active target choice | `TargetSelector` |
| Camera/TFLite boundary | `CameraGameScreen`, `YoloStreamingFrameAdapter`, `YoloModelConfig` |
| Evidence capture | `SessionEvidenceFrame`, `JsonlPerceptionEvidenceRecorder` |
| Child UI/debug UI | `lib/presentation/**` |
| Animation/audio/haptics | cleanup event bus → feedback adapters |
| Progress/reward/streak policies | `lib/domain/progress/**` |
| Progress completion use case | `CompleteCleanupSessionUseCase` |
| Durable progress and migrations | `SqliteProgressRepository`, `SqliteMigrations` |
| Corpus/device certification | `tools/toyvision_certify.dart`, `tools/certify_galaxy_s25.ps1` |

## Critical control flow

```text
YOLOView onStreamingData
→ YoloStreamingFrameAdapter (pixels + all valid boxes)
→ HybridToyPerceptionEngine
  → NativeProposalObjectDetector
  → VisualFrameAnalyzer
  → SceneStabilityService
  → ToyCandidateFusion
  → ToyTracker / TrackAssociator
  → OcclusionReasoner / ToyRemovalVerifier
  → RoomWorldModel + PerceptionTrace
→ CleanupSessionService
  → discovered RoomSnapshot (expanded only by stable `NewToyDiscovered` evidence)
  → interprets removal/room-clean evidence
  → sole owner of collection and completion events
→ CleanupController
  → CompleteCleanupSessionUseCase
  → deterministic progress policy
  → SQLite transaction (session + room + ledger + streak + achievements)
→ committed `CleanupCompleted` through DomainEventBus
→ feedback, celebration, and refreshed UI progress
```

`ToyCollected` is created in production only at
`lib/application/cleanup/cleanup_session_service.dart`. UI, detector, fusion,
tracker, and feedback code are forbidden from constructing it.

## Progress invariants

- Domain and application contracts do not import SQLite, SQL, Flutter, or
  Riverpod.
- SQLite is the only persistent progress authority. SharedPreferences is
  limited to presentation settings and one-time legacy import.
- Completion is keyed by cleanup session ID; reprocessing cannot duplicate
  stars, sessions, streak changes, or achievements.
- The SQLite transaction must commit before completion feedback is published.
- Reward ledger history is append-only; displayed totals are derived from it.
- Daily streak changes are based on local calendar dates, not elapsed 24-hour
  windows or number of rooms cleaned in one day.
- Schema evolution is owned by versioned `SqliteMigrations`.

## Observed architecture debt

The target layering is not yet fully enforced:

- `infrastructure/feedback/cleanup_feedback_coordinator.dart` imports both an
  application provider and the presentation `AnimationDirector`.
- presentation directly imports Ultralytics and several infrastructure
  adapters to host the camera surface.
- domain cleanup services import `core/math/vector_math.dart`, so the stronger
  statement “domain imports only Dart SDK” is not literally true.
- reusable visual tokens/components remain split between `lib/ui/**` and
  `lib/presentation/**`.

These are explicit audit findings, not permission for broad rewrites. Correct
them only with an owner/consumer migration and regression evidence.

## Change rules

- Preserve public behavior unless the request changes it.
- Add abstractions at the consumer-owned boundary; do not move domain decisions
  into adapters for convenience.
- One owner per state transition and event.
- No simultaneous write agents on the same owner.
- A migration removes replaced implementations and updates tests/docs in the
  same change; it does not leave parallel truth paths.
