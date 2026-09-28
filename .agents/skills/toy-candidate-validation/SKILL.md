---
name: toyvision-toy-candidate-validation
description: Validate whether visual proposals can become confirmed ToyObservation evidence without label rules or unsupported open-set semantics.
---

# PURPOSE

Protect `Proposal != Toy` and `Candidate != ConfirmedToy` at fusion boundaries.

# WHEN TO USE

Use when changing candidate fusion, open-set proposals, embeddings, semantic
confidence, prototype memory, or confirmation blockers.

# INPUTS

- Candidate fields and source from `FrameAnalysis`.
- Persistence, detector/proposal score, scene context, embedding/prototype
  similarity, blockers, and expected evidence stage.
- Positive and hard-negative examples across multiple frames.

# PROCEDURE

1. Identify which input provides toy semantics versus identity/objectness.
2. Compute the fusion score and each blocker for a concrete candidate.
3. Run the same numeric evidence with different labels; the result must match.
4. Verify open-set-only candidates remain unconfirmed unless an explicitly
   validated semantic source is added.
5. Test temporal persistence, scene instability, weak proposal support, and
   prototype-memory behavior independently.
6. Add focused tests for the corrected contract and run replay regressions.

# TOOLS

`lib/perception/fusion/**`, `test/perception/candidate_fusion_test.dart`,
developer evidence JSONL, corpus evaluator, and `rg` for label decisions.

# EXPECTED OUTPUT

Evidence-source table, explicit score/blockers, label-invariance result,
positive/negative cases, and confirmation verdict.

# FAILURE CONDITIONS

Fail when names/keywords/regex affect acceptance, an identity embedding is
treated as semantic proof without validation, or one frame confirms a toy.

# QUALITY GATES

Candidate fusion tests pass; hard-negative false positives do not regress;
open-set-only contract is explicit; full replay and static gates pass.
