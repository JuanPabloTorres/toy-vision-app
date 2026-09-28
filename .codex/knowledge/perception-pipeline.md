# Perception pipeline

```text
YOLOView streaming payload
→ YoloStreamingFrameAdapter
   requires originalImage pixels
   keeps every valid normalized detection regardless of class name
→ NativeProposalObjectDetector
→ VisualFrameAnalyzer (isolate)
   decodes image
   computes scene/crop perceptual descriptors
   optionally generates grid open-set regions
→ SceneStabilityService
   fuses visual motion with Android IMU / rotation-vector evidence
→ ToyCandidateFusion
   numeric evidence + temporal memory + confirmation blockers
→ ToyTracker / TrackAssociator
   IoU + centroid + embedding + size
→ SensorFusionEngine / OcclusionReasoner / ToyRemovalVerifier
   device motion + background reveal + optional pose/depth evidence
→ RoomWorldModel + metrics + PerceptionTrace
→ RoomCoverageTracker
   directional coverage or visual-viewpoint fallback
```

The scheduler targets 3–12 FPS depending on discovery, possible disappearance,
active tracks, thermal and battery conditions. Open-set work is disabled under
serious/critical thermal pressure.

The engine's `discoveryMode` input only controls scene-anchor/proposal strategy.
It is not a game phase and does not start or stop continuous vision.

Important current contract: the engineered perceptual descriptor is useful for
visual identity and scene comparison but is not validated semantic toy-likeness.
Consequently open-set-only candidates remain uncertain. YOLO supplies current
semantic detector confidence; `knownClass` remains diagnostic.

When diagnosing, compare each stage frame by frame and stop at the first value
that contradicts ground truth. Threshold changes are downstream policy, not a
substitute for verifying preprocessing/decoding/evidence.

The current `ultralytics_yolo` surface owns a CameraX session. Android motion
sensors run alongside it, but ARCore Shared Camera requires a Camera2-owned
session and disables hardware depth while sharing. Pose/depth fields therefore
remain optional capability hooks; absence must preserve the complete visual +
IMU fallback and can never fabricate evidence.
