# Toy Vision project instructions

Toy Vision is a kid-first cleanup game, not a computer-vision dashboard. Start
with `.codex/README.md` and load only the routed document or skill needed for
the task.

## Non-negotiable invariants

- `Proposal != Toy`; `Candidate != ConfirmedToy`.
- `Missing`, `Occluded`, `LostTrack`, and `SceneChanged` never imply
  `Collected`.
- Zero confirmed toys never implies `CleanupCompleted`.
- Production `ToyCollected` events are owned exclusively by
  `lib/application/cleanup/cleanup_session_service.dart` after confirmed
  disappearance evidence for an initial-snapshot identity.
- YOLO labels are diagnostic only. Do not add label names, keywords, regexes,
  or screenshot-specific rules to perception decisions.
- Kid Mode and Developer Vision Debug are separate surfaces.
- Animation, audio, and rewards react to domain events, never directly to
  detector output.
- SQLite is the sole local source of truth for child progress. Session,
  room, reward ledger, streak, and achievement updates commit atomically
  before `CleanupCompleted` is published or celebration begins.
- Riverpod, widgets, controllers, SharedPreferences, and loose files never
  own or directly mutate child progress.
- Do not claim physical-device, perception, or commercial readiness from a
  desktop build or unit tests.

## Routing

- Architecture or ownership: `.codex/ARCHITECTURE.md` and
  `$toyvision-architecture-audit`.
- Perception or YOLO: `.codex/knowledge/perception-pipeline.md` and the
  matching skill in `.agents/skills/`.
- False/automatic collection: `$toyvision-false-collection-investigation`.
- Tracking or identity: `$toyvision-tracking-reidentification`.
- UI/gameplay: `.codex/knowledge/gameplay-flow.md` and
  `$toyvision-flutter-gameplay-ui`.
- Validation/release: `.codex/QUALITY_GATES.md` and
  `$toyvision-release-certification`.

## Working agreement

Inspect the current working tree before editing and preserve unrelated work.
Use the smallest relevant tests while iterating, then run the gates required by
`.codex/QUALITY_GATES.md`. Report `PASS`, `PARTIAL`, `FAIL`, or `BLOCKED` with
evidence; compilation alone is never PASS.

## Required change workflow

- Analyze the request and inspect the affected system, repository instructions,
  current branch, and working tree before editing.
- Create one purpose-specific branch from `main` before changing files. Use the
  prefixes `feature/`, `fix/`, `bugfix/`, `dev/`, `qa/`, `release/`, `docs/`, or
  `chore/` as appropriate. Do not develop directly on `main`.
- Treat one completed user request as one versioned change. Update the semantic
  version once per change branch: MAJOR for breaking behavior, MINOR for a
  backward-compatible feature, and PATCH for a backward-compatible fix. Always
  increment Flutter's build number after `+`.
- Run the relevant quality gates before merging. Merge only reviewed, validated
  work and preserve evidence of any blocked release gates.
- Merge the completed branch into `main` without force-pushing. Do not delete the
  historical `master` branch unless its removal is requested separately.

The detailed procedure is in `docs/development_workflow.md`.
