# Skill: preserve-ai-model-discipline

## Purpose
Keep the model a detector that proposes raw detections — never the decision-maker.

## When to use
Any time you touch detectors, the model output contract, the adapter, or the class list.

## Required rules
- Mock detector first; real model only after the foundation is proven
  ([ai-model-guidelines.md](../ai-model-guidelines.md)).
- Detector returns raw detections only (`label`, `confidence`, normalized `box`).
- Keep `MockToyDetector` output swap-compatible with the real detector.
- Sync class-list changes with `ToyCategoryRegistry` in the same change.
- Wrap native runtimes via an adapter.

## Forbidden patterns
- The model deciding final count or user-facing certainty.
- Face recognition or person identification.
- Saving or uploading frames during inference.
- Connecting the real model before tracking/counting works.
- Class/label drift from the registry.

## Acceptance criteria
- The detector emits raw detections in the contract shape.
- Mock and real detectors are interchangeable.
- The class list and registry stay in sync.
- The model performs no product decisions and no people detection.
