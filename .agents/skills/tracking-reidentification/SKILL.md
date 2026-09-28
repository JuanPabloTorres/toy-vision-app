---
name: toyvision-tracking-reidentification
description: Diagnose and improve Toy Vision association, identity continuity, reappearance, ID switches, duplicate tracks, and collected-object memory.
---

# PURPOSE

Preserve one physical toy as one identity through motion, occlusion, ordering
changes, temporary disappearance, and reentry.

# WHEN TO USE

Use for ID switches, duplicate collections, track fragmentation, wrong
reidentification, overlapping toys, or association-threshold changes.

# INPUTS

- Ordered observations/tracks for every relevant frame.
- IoU, centroid, size, embedding similarity, total score, and assignment.
- Track lifecycle fields, scene state, and collected signatures.

# PROCEDURE

1. Build a per-frame identity timeline with expected physical IDs.
2. Recompute every candidate association and the greedy assignment order.
3. Locate the first incorrect match, unmatched observation, or new-track spawn.
4. Separate descriptor failure from assignment strategy, lifecycle state, and
   scene/occlusion failure.
5. Test the smallest correction against crossing, overlap, reordered inputs,
   disappearance/reappearance, and collected-looking reentry.
6. Count ID switches, duplicate tracks, and duplicate collections before/after.

# TOOLS

`TrackAssociator`, `ToyTracker`, `CollectedObjectMemory`, trace associations,
`tracking_and_disappearance_test.dart`, replay/corpus evaluator metrics.

# EXPECTED OUTPUT

Identity timeline, association matrix, first bad assignment, correction,
before/after ID-switch/duplicate counts, and residual ambiguity.

# FAILURE CONDITIONS

Fail if identity is matched by label, ambiguity is hidden through reset, a
collected identity can be counted twice, or evidence is only a final count.

# QUALITY GATES

Reordered/crossing/reappearance tests, duplicate protection, adverse replay,
corpus ID-switch and duplicate limits, static gate, and no false collection.
