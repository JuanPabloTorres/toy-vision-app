# Domain model

| Concept | Meaning | Owner |
|---|---|---|
| `DetectorProposal` | normalized box + numeric confidence + optional diagnostic class | perception boundary |
| `VisualCandidate` | proposal enriched with objectness/embedding/source | perception |
| `ToyObservation` | candidate evidence and confirmation blockers for one frame | domain toy value |
| `ToyTrack` | persistent physical identity and lifecycle | tracking/domain |
| `SceneDescriptor` | scene embedding, motion, stability, coverage and anchor similarity | scene reasoning |
| `RoomSnapshot` | immutable initial set of stable confirmed tracks | domain scene |
| `RoomWorldModel` | active/missing/collected track maps plus current scene | perception output/domain value |
| `DisappearanceEvidence` | auditable proof/blockers for a missing track | perception |
| `CleanupSession` | initial snapshot and confirmed collected IDs | domain cleanup |
| `CleanupEvent` | domain facts consumed by state/feedback/UI | domain cleanup |

`CleanupSessionService` is the authorized production owner of `ToyCollected`
and `CleanupCompleted`. `CleanupController` orchestrates frames, publishes
events, persists completed summaries, and exposes `CleanupState`. Feedback
adapters consume events; they do not decide progress.

The current `ToyTrack.isStable` contract is confirmed toy + at least six
visible frames + confidence ≥ 0.68. Treat this as current behavior, not a
universal truth: any change needs replay/corpus evidence.
