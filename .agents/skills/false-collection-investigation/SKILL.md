---
name: toyvision-false-collection-investigation
description: Investigate automatic or false ToyCollected events by tracing the event backward to the first incorrect disappearance, track, candidate, detection, or raw proposal fact.
---

# PURPOSE

Find and prove the root cause of the product's highest-risk defect: progress
without a real pickup.

# WHEN TO USE

Use whenever the game advances, rewards, or completes while no toy was picked
up, or when duplicate collection is suspected.

# INPUTS

- Event timestamp and track ID, session/snapshot, exact build/model/environment.
- JSONL trace and consented frames when available.
- Disappearance, track association/lifecycle, candidate, detection, and native
  proposal history around the event.

# PROCEDURE

1. Freeze/reproduce the scenario and preserve unmodified evidence.
2. Start at `ToyCollected`; confirm it originated in `CleanupSessionService`.
3. Inspect the accepted `DisappearanceEvidence` and recompute all blockers.
4. Walk backward through track identity/interaction/missing history.
5. Walk backward through accepted/uncertain observation, fused candidate,
   decoded detection, and raw proposal/preprocessing when available.
6. Mark the first state that contradicts physical ground truth.
7. Form and isolate one hypothesis; do not tune thresholds first.
8. Assign the correction to its actual owner and implement the smallest change.
9. Replay the original trace plus pan, shake, cover, occlusion, low light,
   reappearance, duplicate, and completion regressions.
10. Request independent adversarial/release review when multi-agent execution is
    authorized.

# TOOLS

`JsonlPerceptionEvidenceRecorder`, `SessionEvidenceFrame`, developer overlay,
`rg -n 'ToyCollected\(' lib`, replay harness, corpus evaluator, and templates
`investigation.md`/`regression-report.md`.

# EXPECTED OUTPUT

Backward causal chain, first incorrect fact, ruled-out causes, patch owner,
before/after event timeline, scenario matrix, and verdict.

# FAILURE CONDITIONS

Return `BLOCKED` if decisive evidence was not captured. Fail any fix where
missing, movement, occlusion, low confidence, lost track, or scene change alone
can still create collection.

# QUALITY GATES

Zero unexpected/duplicate collections in applicable automated and corpus
scenarios; no premature completion; static/replay/adversarial gates pass; device
claims require device evidence.
