# Tracking model

`TrackAssociator` scores every non-collected track/observation pair:

```text
score = 0.30*IoU + 0.20*centroid + 0.40*cosineEmbedding + 0.10*size
minimum score = 0.42
```

Candidates are greedily assigned from highest score. This is deterministic but
can be globally suboptimal in crowded/overlapping scenes; inspect the entire
candidate matrix before changing weights.

Lifecycle:

```text
candidate → visible
visible → missingCandidate (stable scene) or occluded (unstable scene)
missing/occluded → visible on association
missingCandidate → confirmedMissing only after DisappearanceVerifier
confirmedMissing → collected only after CleanupSessionService accepts evidence
```

Only confirmed observations spawn new tracks. Collected tracks remain in the
tracker and `CollectedObjectMemory` compares ID, embedding, bounds, and time to
reduce duplicate collection. Identity quality is measured with ID switches,
duplicate tracks/collections, and reappearance continuity—not final counts.
