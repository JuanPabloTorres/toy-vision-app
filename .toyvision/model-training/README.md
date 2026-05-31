# Model Training — Index

This folder holds the **standards** for how a real ToyVision detector would be
built, evaluated, exported, and versioned. It is governance, not code.

## Purpose

Define and pin down the rules for:

- dataset sourcing, sizing, and balance;
- class taxonomy aligned with the business layer;
- labeling conventions and quality bars;
- privacy and consent rules for any image used in training;
- training pipeline, hyperparameters, and reproducibility;
- evaluation metrics and accept/reject gates;
- TFLite export contract matching the app's runtime expectations;
- model versioning, provenance, and rollback.

## Current status

- **No model has been trained yet.**
- **No `.tflite` file is committed** to the repository.
- **Nothing in this folder changes app runtime behavior.**
- The default detector is `MockToyDetector`. Real inference is gated behind a
  fallback path and is **not** enabled.

## Preconditions

- **Phase 2d physical-device QA is BLOCKED.** There is no Android device and
  no usable emulator available to validate the end-to-end pipeline on real
  hardware.
- Real model inference (`TfliteToyDetector` via `TfliteToyDetectorAdapter`)
  must **not** be enabled until that gate passes.
- Until then, every document here is a forward-looking specification — it
  must not be read as evidence that a model exists or has been validated.

## Architecture rule reminder

The model **only detects**. It returns boxes, class indices, and scores.
It does **not** decide:

- the final toy count;
- whether a detection is a "real" toy worth counting;
- whether confidence is acceptable for the user;
- duplicate identity across frames;
- ignored categories.

Those decisions live in the business layer:

- `lib/business/toy_category_registry.dart` — `ToyCategoryRegistry`
- `lib/business/toy_detection_rules.dart` — `ToyDetectionRules`
- `lib/tracking/toy_tracking_engine.dart` — `ToyTrackingEngine`
- `lib/business/toy_counting_service.dart` — `ToyCountingService`

If a document in this folder appears to encode a business decision, the
business layer wins.

## Contents

| Document | Scope |
| --- | --- |
| [dataset-plan.md](dataset-plan.md) | Sources, sizes, splits, balance targets. |
| [class-taxonomy.md](class-taxonomy.md) | Canonical class list and ignored categories. |
| [labeling-guidelines.md](labeling-guidelines.md) | Box rules, edge cases, QA. |
| [privacy-rules.md](privacy-rules.md) | Consent, faces, children, opt-out. |
| [training-pipeline.md](training-pipeline.md) | Repro setup, hyperparameters, seeds. |
| [evaluation-plan.md](evaluation-plan.md) | Metrics, slices, accept gates. |
| [export-to-tflite.md](export-to-tflite.md) | Input/output contract for the app. |
| [model-versioning.md](model-versioning.md) | Provenance, naming, rollback. |
| [known-risks.md](known-risks.md) | Open risks, biases, blockers. |

## How this folder relates to governance

These docs are subordinate to the cross-cutting governance files:

- [../ai-model-guidelines.md](../ai-model-guidelines.md) — detector contract,
  phase rule, mock-first policy.
- [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md) —
  non-negotiable privacy rules that bind any dataset or training work.
- [../business-logic-principles.md](../business-logic-principles.md) —
  why the model never makes business decisions.

Where this folder and a governance doc disagree, **the governance doc wins**
and this folder must be updated.
