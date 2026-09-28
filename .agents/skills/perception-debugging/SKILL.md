---
name: toyvision-perception-debugging
description: Diagnose Toy Vision perception failures causally across camera pixels, proposals, embeddings, fusion, tracking, scene reasoning, and world-model output.
---

# PURPOSE

Find the first incorrect pipeline state and fix its owner with replayable
evidence.

# WHEN TO USE

Use for missed/extra toys, unstable tracks, unexplained candidates, bad scene
state, incorrect disappearance, or any end-to-end perception regression.

# INPUTS

- Exact symptom, expected physical result, build/model hash, and environment.
- Reproduction or consented JSONL/frame capture.
- `PerceptionTrace`, metrics, world model, events, and relevant thresholds.

# PROCEDURE

1. Reproduce with a deterministic replay or named physical scenario.
2. Capture trace from pixels/proposals through events; do not infer absent raw
   stages.
3. Compare expected and actual state per frame and identify the first mismatch.
4. Trace upstream evidence and downstream consumers from that mismatch.
5. Form one falsifiable numerical hypothesis.
6. Test it by isolating the owning stage, preserving a before trace.
7. Implement the smallest architectural correction at that owner.
8. Replay the original failure and compare event/track timelines.
9. Run neighboring adversarial regressions.
10. Report evidence and every unexecuted device/corpus gate.

# TOOLS

`DeveloperVisionOverlay`, `SessionEvidenceFrame`, opt-in
`JsonlPerceptionEvidenceRecorder`, `test/support/camera_replay.dart`, focused
`flutter test`, and `tools/toyvision_certify.dart` for a complete real corpus.

# EXPECTED OUTPUT

Reproduction, first incorrect state, causal chain, hypothesis/test, focused
patch, before/after trace, regression matrix, and verdict.

# FAILURE CONDITIONS

Stop as `BLOCKED` when pixels/trace needed to distinguish hypotheses are
unavailable. Fail if the fix is label/regex/screenshot-specific or merely
changes thresholds without identifying the incorrect stage.

# QUALITY GATES

Original replay passes; label invariance, camera pan/occlusion, identity, false
collection, completion, static, and applicable corpus/device gates pass.
