---
name: toyvision-scene-stability
description: Diagnose scene-anchor, motion, camera pan/shake/cover, low-light, blur, and reobservation behavior that gates disappearance and completion.
---

# PURPOSE

Separate physical object change from camera/scene change and prevent unstable
views from verifying disappearance.

# WHEN TO USE

Use for pan/shake false positives, frozen or never-stable scans, camera cover,
bad anchor recovery, or scene-related completion failures.

# INPUTS

- Ordered scene embeddings, previous/anchor similarity, motion, stability
  counter, coverage, luminance, sharpness, and timestamps.
- Expected camera action and object state for each interval.

# PROCEDURE

1. Plot/tabulate scene values by frame around the transition.
2. Identify anchor creation/update and every `SceneState` transition.
3. Verify obscured frames and motion cannot increment verification stability.
4. Check return-to-anchor behavior separately from object-region change.
5. Isolate descriptor weakness versus state-window/threshold behavior.
6. Test stationary, pan, shake, cover/uncover, blur, low light, person crossing,
   and stable return before changing policy.

# TOOLS

`SceneStabilityService`, `VisualFrameAnalyzer`, JSONL scene fields, adverse
replay, developer overlay, and real-device capture for camera behavior.

# EXPECTED OUTPUT

Scene timeline, anchor/state explanation, first incorrect transition,
correction and scenario matrix.

# FAILURE CONDITIONS

Fail if moving/obscured views verify disappearance, the anchor silently tracks
a pan, or synthetic desktop evidence is presented as CameraX/device proof.

# QUALITY GATES

Pan/shake/cover/low-light/return scenarios pass; no false collection or
premature completion; performance and device gates run when cadence changes.
