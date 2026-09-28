# Toy Vision 3.0 — SOW architecture audit

Audit date: 2026-09-27

This document records the repository state before the Toy Vision 3.0 SOW
migration. The two SOW attachments supplied with the implementation request are
the architectural source of truth.

## Observed current architecture

The app starts in `main.dart`, installs persistence overrides, and renders an
`AppShell` with child/adult tabs. Kid Mode passes native `YOLOView` callbacks
through `YoloPerceptionAdapter` into `KidGameController`. That controller owns
tracking, temporal windows, mission selection, count-based progress, rewards,
session persistence, and every UI phase. Audio is invoked by the camera widget
after observing controller counters.

The live path is therefore:

```text
YOLOView -> label mapper -> label registry/rules -> KidGameController
         -> count snapshots -> KidGamePhase -> widget/audio side effects
```

This path has useful camera/model integration and a green test baseline, but it
does not implement the required hybrid/open-set pipeline. In particular, it
does not receive pixels for crops, has no visual embeddings, makes perception
decisions with label allowlists, tracks without appearance embeddings, infers
progress from aggregate count decreases, and has no per-track disappearance
verification or world model.

## Classification

| Component | Decision | Evidence and target |
|---|---|---|
| `lib/main.dart` bootstrap | REFACTOR | Keep synchronous persistence startup; install only final providers. |
| `lib/app/app_theme.dart`, `lib/ui/theme/**` | MIGRATE | Visual tokens are reusable; move ownership under presentation/app without changing colors. |
| `lib/app/app_router.dart`, `lib/app/toyvision_app.dart` | REFACTOR | Replace shell/tab routing with Home -> Scan/Cleanup -> Celebration and adult-only Settings. |
| `lib/ui/screens/home_screen.dart` | REFACTOR | Retain visual identity and Tobi; remove dashboard/tab/intro dependencies and make Start authoritative. |
| `lib/ui/screens/mission_intro_screen.dart` | DELETE | Extra child step contradicts the SOW's simplified flow. |
| `lib/ui/navigation/app_shell.dart`, `app_bottom_navigation.dart` | DELETE | Child navigation exposes legacy Progress/Parents and owns mission routing. |
| progress/history/parent screens and panels | MIGRATE | Not child flow; retain only behind adult Settings if still useful. |
| `lib/camera/screens/toy_cleanup_camera_screen.dart` | REFACTOR | Keep native camera surface/model lifecycle; stream real pixels plus detections into the perception facade. |
| `lib/camera/controllers/kid_game_controller.dart` | DELETE | God object owns perception, domain, persistence, rewards, timers, and UI phases. Replace with application `CleanupController`. |
| `lib/detection/yolo/yolo_model_config.dart` | MIGRATE | Keep bundled on-device model resolution; remove network fallback and label vocabulary as decision logic. |
| `YoloPerceptionAdapter`, `YoloDetectionMapper` | DELETE | The mapper is a textual allowlist and discards unknown objects before open-set reasoning. Replace with a pixel-bearing infrastructure adapter. |
| `ToyCategoryRegistry`, `ToyDetectionRules` | DELETE | Labels currently determine whether an observation is a toy. SOW requires numeric evidence fusion. |
| `lib/detection/models/**` | MIGRATE | Preserve normalized geometry concepts, replace detector-centric DTOs with domain/perception models. |
| `lib/tracking/**` | DELETE | Existing association uses geometry/label only and drops missing tracks; replace with embedding-aware tracking and explicit presence state. |
| `lib/business/cleanup/**` | DELETE | Mission-set/count-window design conflicts with per-track world model and disappearance verification. |
| `lib/business/app_audio_service.dart` | MIGRATE | Reuse `audioplayers`; expose the SOW `AudioFeedbackService` interface and consume domain events. |
| `lib/ui/components/tobi_mascot.dart`, image assets | MIGRATE | Keep as accessibility/failure fallback; primary Tobi state must be driven by domain events. |
| Lottie support | KEEP | Already local/offline; connect effects to an animation director rather than phase widgets. |
| Rive and 3D support | MIGRATE | No runtime or assets currently exist. Add event-driven adapters and explicit asset/fallback status. |
| `lib/storage/**` | MIGRATE | Settings/history are useful infrastructure; cleanup domain must depend only on repository interfaces and persist no images. |
| `PerceptionBenchmarkRecorder` | REFACTOR | Keep bounded diagnostics; record all pipeline stages, scheduler policy, drops, and event latency without label-based decisions. |
| existing tests | MIGRATE | Keep geometry/storage/theme coverage; replace mission/count tests with pipeline, tracking, reobservation, occlusion, scene-change, duplicate, replay, and flow tests. |
| custom `assets/models/toys.tflite` | KEEP | It is a real bundled on-device detector. It becomes one evidence source, never the sole truth. |
| COCO network fallback / INTERNET permission | DELETE | Basic function must be offline and model behavior deterministic. |

## Highest-impact findings

1. **Blocker — no pixel access in the application callback.** The existing
   `onResult` path exposes boxes only. Embeddings, scene similarity, local
   reobservation, and open-set proposals cannot be real. The installed plugin
   supports `onStreamingData` with `includeOriginalImage`; the camera host must
   use it at a bounded adaptive inference rate.
2. **Blocker — progress is aggregate-count based.** Two low snapshots can
   grant progress even when no original physical identity was verified absent.
3. **Blocker — textual gating.** `YoloDetectionMapper` and
   `ToyCategoryRegistry` decide acceptance through exact names and allowlists.
4. **High — mixed ownership.** `KidGameController` owns camera-derived
   tracking, session/domain decisions, reward timing, persistence, and UI phase
   transitions. This prevents isolated proof of the cleanup decision.
5. **High — missing scene memory.** Missing tracks are eventually dropped, so
   there is no durable `RoomWorldModel`, reobservation proof, or collected
   signature memory.
6. **High — child flow contains mission selection/reveal/countdown and a bottom
   navigation shell.** These are explicitly excluded by the SOW.
7. **High — Tobi/audio are widget/phase effects.** They are not subscribers to
   domain events. Rive and a real 3D runtime are absent.
8. **High — no evaluation corpus or camera replays.** Unit tests are numerous
   but synthesize count windows rather than replaying adverse perception data.
9. **Medium — model fallback requires network and changes the detector
   vocabulary.** This violates deterministic offline basic operation.
10. **Medium — performance telemetry exists but no thermal/battery input drives
    inference policy.** Existing device result templates contain unfilled
    placeholders and are not release evidence.

## Target dependency rule

```text
presentation -> application -> domain
camera/tflite/audio/persistence infrastructure -> domain/application ports
perception -> domain value models
domain -> Dart SDK only
```

No presentation component may create a `ToyCollected` event. Only verified
track disappearance in a stable, reobserved scene may do so.

## Progress persistence addendum

The progress system follows the same dependency rule:

```text
presentation/Riverpod -> application use case -> domain policy + repository port
SQLite adapter -> repository port
```

SQLite is the sole durable progress authority. Completing a cleanup writes the
session, room aggregate, append-only reward ledger, daily streak, and newly
unlocked achievements in one transaction keyed by session ID. Replaying the
same completion is a no-op. `CleanupCompleted` reaches feedback and celebration
only after that transaction commits; a failed commit leaves the UI in a
non-celebrating error state. SharedPreferences is limited to UI settings and a
one-time, idempotent migration of legacy completed-session summaries.

Reward and streak decisions are pure domain policies. Streaks use local
calendar days and advance no more than once per day. Widgets, Riverpod
controllers, perception, and detector callbacks cannot write SQL or award
stars.

## Validation gates

Every migration phase must run formatter, analyzer, unit/integration tests, and
an Android build. Release readiness additionally requires a physical Galaxy S25
run for camera permissions, model load, thermal behavior, battery, FPS, memory,
open-set recall, occlusion, camera motion, disappearance latency, and audio/3D
rendering. Local compilation cannot substitute for that device evidence.
