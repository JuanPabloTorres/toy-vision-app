---
name: toyvision-disappearance-verification
description: Validate the temporal, scene, local-region, interaction, occlusion, and reidentification evidence required to confirm a toy disappearance.
---

# PURPOSE

Ensure `Missing != Collected` by proving a specific initial-snapshot identity
was physically removed rather than hidden, lost, or displaced by the camera.

# WHEN TO USE

Use when changing missing windows, local reobservation, interaction evidence,
occlusion, scene stability, or `DisappearanceVerifier`.

# INPUTS

- Track history including confirmation and interaction timestamps.
- Scene similarity/motion/stable frames and local-region embedding.
- Missing duration/frames, occlusion, reidentification candidates, blockers.

# PROCEDURE

1. Verify the track is a confirmed initial-snapshot toy with stable history.
2. Reconstruct the missing interval frame by frame.
3. Prove the camera returned to a stable anchor and reobserved the original
   region.
4. Measure local visual change and recent physical-interaction evidence.
5. Exclude occlusion and plausible reidentification.
6. Recompute confidence and every rejection reason; confirmation is permitted
   only when the blocker list is empty.
7. Test pan, shake, cover, hand/person occlusion, blur, low light, reappearance,
   and true pickup.

# TOOLS

`DisappearanceVerifier`, `SceneDescriptor`, `ToyTrack`, evidence JSONL,
tracking/disappearance tests, adverse replay, and corpus collection metrics.

# EXPECTED OUTPUT

Frame timeline, evidence/blocker table, confirmation decision, first wrong
fact, focused correction, and adverse scenario results.

# FAILURE CONDITIONS

Fail if absence alone confirms removal, the original region was not
reobserved, interaction is fabricated, or occlusion/reidentification is ignored.

# QUALITY GATES

True pickup passes; every non-pickup scenario emits no `ToyCollected`; original
replay and full false/duplicate collection gates pass.
