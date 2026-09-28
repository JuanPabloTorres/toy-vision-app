---
name: toyvision-replay-testing
description: Capture, construct, run, and assess deterministic Toy Vision camera replays through the production perception and cleanup decision path.
---

# PURPOSE

Turn a perception/gameplay failure into repeatable frame/event evidence while
preserving the production processing path.

# WHEN TO USE

Use for regressions, bug reproduction, causal comparisons, corpus captures, or
verification that a fix survives the original frame sequence.

# INPUTS

- Expected physical objects/actions and event timeline.
- Synthetic fixture or explicit-consent captured session with pixels,
  detections, timestamps, and annotations.
- Build/model hash and acceptance criteria.

# PROCEDURE

1. Prefer exact captured pixels/proposals for real failures; identify synthetic
   fixtures as contract tests.
2. Preserve timestamps, frame order, camera movement, object identities, and
   expected collection/completion events.
3. Feed frames through `HybridToyPerceptionEngine` and
   `CleanupSessionService`, not a parallel fake decision path.
4. Record tracks, associations, scene state, disappearance evidence, and events.
5. Assert sequence/idempotency and absence of forbidden events, not only totals.
6. Run before/after with the same replay and add the smallest neighboring
   adverse variant.
7. For corpus claims, validate split isolation and complete human annotations.

# TOOLS

`test/support/camera_replay.dart`, `test/fixtures/replays/**`, integration tests,
opt-in JSONL recorder, `tools/toyvision_certify.dart validate/evaluate/template`.

# EXPECTED OUTPUT

Replay provenance, expected/actual timeline, deterministic command/result,
before/after diff, added regression, and limitations.

# FAILURE CONDITIONS

Fail if replay bypasses production owners, lacks physical ground truth, reuses
captures across corpus splits, stores pixels without consent, or a synthetic
fixture is called real-world certification.

# QUALITY GATES

Original and adjacent replays pass; false/duplicate/premature events remain
zero; corpus schema validates when used; privacy/static/full tests pass.
