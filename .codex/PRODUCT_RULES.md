# Product rules

## Child experience

- The primary loop is `SEE → FIND → PICK UP → REACT → REWARD → CONTINUE`.
- Tobi, encouragement, progress, and one obvious next action dominate.
- Child copy is short, positive, and does not claim perfect room knowledge.
- Avoid mission-selection ceremony, technical counters, boxes, labels, and
  confidence values in Kid Mode.
- Every reachable child screen must have a clear next action or exit.
- Settings and developer diagnostics are not part of the child loop.

## Perception truth

- A detector proposal is evidence, not a toy.
- An open-set region without semantic evidence remains a candidate.
- Labels may be displayed diagnostically but never change acceptance,
  association, collection, or completion.
- Collection requires a confirmed initial-snapshot identity, stable observation
  history, stable/reobserved scene, local visual change, a sufficient missing
  window, recent interaction evidence, no occlusion, and no plausible
  reidentification candidate.
- Missing, occlusion, camera movement, low confidence, a lost track, or a scene
  change cannot independently award progress.
- Completion requires a non-empty credible initial snapshot, verified progress,
  every snapshot identity collected, no remaining/ambiguous/new confirmed toy,
  and a scene verified against the snapshot.

## Privacy and safety

- On-device processing is the default; no live-loop backend dependency.
- No face/child/person identification.
- No silent frame, video, audio, or embedding retention or upload.
- Certification pixel capture requires explicit build flags and operator
  acknowledgement; its artifacts are sensitive and temporary.
- Persist only privacy-safe completed-session summaries.

## Feedback

Animation, 3D, Rive, Lottie, audio, and haptics consume `CleanupEvent`s.
Detector callbacks must never trigger rewards directly. Reduced-motion and
asset/runtime fallbacks must preserve a usable flow.

## Durable progress

- SQLite is the sole persistent source of truth for child progress; Riverpod
  providers and widgets only present application state.
- A completed session, room progress, reward ledger, streak, and achievements
  commit in one transaction. A retry of the same session ID is idempotent.
- Daily streaks use local calendar days and can advance at most once per day.
- Reward and streak rules are deterministic domain policies with no Flutter or
  SQL dependency.
- `CleanupCompleted` and its celebration are published only after the progress
  transaction commits. Persistence failure must remain a non-celebrating error.
- Schema changes use versioned migrations; historical ledger/session rows are
  retained rather than replaced by mutable counters.
