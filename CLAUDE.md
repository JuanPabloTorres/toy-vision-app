# CLAUDE.md — Toy Vision

Toy Vision is a local-first Flutter game in which cleaning any supported toy
charges Tobi. Computer vision is a silent sensor; Tobi is the child-facing game.

## Authoritative production flow

```text
YOLO camera observations
→ mapping and validation
→ physical tracking and scene quality
→ RoomSnapshotBuilder
→ immutable RoomSnapshot
→ CleanupProgressEngine
→ KidGameController / KidGamePhase
→ ToyBotRewardService
→ Kid UI
→ reinforced final check
→ human confirmation
→ celebration
```

There is one primary cleanup state machine: `KidGamePhase`. Do not introduce
per-object pickup goals, selected-object guidance, child-facing detection boxes,
or a second definition of progress/completion.

## Boundaries

- `lib/detection/`: model lifecycle and raw mapping.
- `lib/tracking/`: physical identity across frames.
- `lib/business/cleanup/`: snapshot, progress, quality, and reward rules.
- `lib/camera/controllers/`: orchestration only.
- `lib/ui/` and `lib/camera/screens/`: presentation only.
- `lib/storage/`: privacy-safe session estimates and preferences; never media.
- `lib/core/config/`: all thresholds and timings.

## Non-negotiable rules

- Understand impact and state objective, files, risk, tests, and acceptance before editing.
- Do not put inference or business rules in widgets.
- Preserve one-way data flow and one authoritative owner per product concept.
- Do not modify the model artifact without explicit authorization and evaluation evidence.
- Keep inference on-device; never save or upload camera media by default.
- Camera-loop changes require latency, memory, FPS, and throttling review.
- Reuse the component system; do not add dependencies without need.
- Every behavior change needs focused tests; finish with `flutter analyze` and `flutter test`.
- Do not commit without explicit confirmation.

The active governance is in `.toyvision/`. Historical research under
`.toyvision/archive/` is not production architecture.
