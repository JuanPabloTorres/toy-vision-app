# Business Logic Principles

## Evidence contract

A raw detection becomes room evidence only after label mapping, category and
confidence validation, valid normalized geometry, tracking, repeated temporal
observation, and scene-quality qualification. One frame is never sufficient.

`ToyCategoryRegistry` is the sole category authority. Unknown and ignored
objects never become supported toys.

## Product truth

- `initialDetectedEstimate`: immutable estimate from the opening snapshot.
- `currentDetectedEstimate`: current qualified estimate.
- `remainingEstimate` and `progressEstimate`: technical comparisons.
- `visibleEnergy`: bounded game state that never decreases.

These values describe what the current model could reliably observe; they are
not proof of total physical-room cleanliness.

## Completion contract

Full energy starts `finalChecking`. Repeated qualified low/zero snapshots are
required before `completionCandidate`. Only explicit human confirmation may
start celebration and completion.

Micro rewards use cooldown/idempotency. The 25/50/75 energy milestones fire at
most once per session. Restart creates a fresh snapshot and reward ledger.
