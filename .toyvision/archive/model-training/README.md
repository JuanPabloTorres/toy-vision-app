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
| [custom-detector-strategy.md](custom-detector-strategy.md) | **Phase 3.7** — Strategy reset: commit to a custom-trained toy detector after the COCO/ML Kit baselines failed. Selects EfficientDet Lite via MediaPipe Model Maker as the primary path. **Read first.** |
| [dataset-capture-pass.md](dataset-capture-pass.md) | **Phase 3.9** — 3-day field manual for capturing the prototype dataset (300–500 images). Folder structure, naming, daily plan, per-image snap test, reject criteria. |
| [dataset-card-template.md](dataset-card-template.md) | **Phase 3.9** — Template for the `dataset-card.md` that lives alongside each dataset snapshot (outside the repo). |
| [colab-training-plan.md](colab-training-plan.md) | **Phase 3.8** — Step-by-step Colab notebook plan for training the prototype. |
| [dataset-validation-checklist.md](dataset-validation-checklist.md) | **Phase 3.8** — Pre-training quality bar that the dataset must clear. Invoked from the Colab plan Cell 3 and from the privacy review. |
| [flutter-integration-plan.md](flutter-integration-plan.md) | **Phase 3.8** — App-side integration: file layout, providers, lessons baked in. Code is written only after the export gates pass. |
| [open-source-model-evaluation.md](open-source-model-evaluation.md) | Phase 3.4–3.6 baseline evaluation; documents why generic models are insufficient for ToyVision. **Status: superseded as a production path.** |
| [dataset-plan.md](dataset-plan.md) | Sources, sizes, splits, balance targets. |
| [class-taxonomy.md](class-taxonomy.md) | Canonical class list and ignored categories. |
| [labeling-guidelines.md](labeling-guidelines.md) | Box rules, edge cases, QA. |
| [privacy-rules.md](privacy-rules.md) | Consent, faces, children, opt-out. |
| [training-pipeline.md](training-pipeline.md) | Repro setup, hyperparameters, seeds. **Updated in Phase 3.8** — MediaPipe Model Maker / EfficientDet Lite 0; the previous YOLO draft is replaced. |
| [evaluation-plan.md](evaluation-plan.md) | Metrics, slices, accept gates. |
| [export-to-tflite.md](export-to-tflite.md) | Input/output contract for the app. **Updated in Phase 3.8** — float32 EfficientDet Lite contract with the Phase 3.5 lessons baked in. |
| [model-versioning.md](model-versioning.md) | Provenance, naming, rollback. |
| [known-risks.md](known-risks.md) | Open risks, biases, blockers. |

## Training tooling lives outside this folder

Python notebooks and dataset utilities go under
[../../tools/training/](../../tools/training/). That directory is **not**
shipped with the Flutter app and never referenced by `lib/`, `assets/`,
or `pubspec.yaml`. Datasets and trained weights never live in the
repository at all.

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
