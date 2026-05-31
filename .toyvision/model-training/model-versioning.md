# Model Versioning

Policy for how every ToyVision detector model is identified, recorded, and
promoted. The model **detects**; this document only governs how a detector
artifact is named, described, and audited — it does **not** define any
business behavior. Business decisions live in the business layer
(see [../business-logic-principles.md](../business-logic-principles.md)).

## Current status

- **No model has been trained or versioned yet.**
- **No `.tflite` file is committed.** The default detector remains
  `MockToyDetector`; TFLite is opt-in via fallback only.
- **Phase 2d physical-device QA is BLOCKED** — no Android device or usable
  emulator. No model may be promoted to default until that gate passes.
- This document defines the convention. It does **not** declare that any
  version exists.

## Where versions are recorded

For now, version records live as **one markdown file per version**:

```
.toyvision/model-training/versions/<model-name>-<version>.md
```

- `<model-name>` is a short slug (e.g. `toy-detector`).
- `<version>` follows `vMAJOR.MINOR.PATCH` (e.g. `v0.1.0`).
- One record per model version. Records are append-only; corrections are made
  by publishing a new version, not editing history.
- **Do not create the `versions/` directory in this phase.** The path is
  documented as the convention; the directory appears only when the first real
  version is recorded.

Later, these records are surfaced programmatically through a
`ModelVersionRepository` (see [../architecture-principles.md](../architecture-principles.md)).
The repository is the runtime read-side; the markdown file remains the
human-authored source of truth.

## Required fields

Every version record **must** contain all of the following. A record missing
any field is incomplete and the model is not promotable.

| Field | Description |
| --- | --- |
| `model_name` | Stable slug (e.g. `toy-detector`). |
| `version` | `vMAJOR.MINOR.PATCH`. |
| `training_date` | UTC ISO-8601 date (e.g. `2026-05-30`). |
| `dataset_size` | Total examples **and** split sizes (`train` / `val` / `test`). |
| `classes` | Canonical class list with **exact** model index order (see below). |
| `input_size` | Tensor shape, e.g. `[1, 320, 320, 3]` float, normalized `(pixel - inputMean) / inputStd`. |
| `output_layout` | Tensor indices and box format (SSD-style, `[ymin, xmin, ymax, xmax]`). |
| `training_metrics` | Final training loss, mAP@0.5, mAP@0.5:0.95. |
| `validation_metrics` | Per-class and overall metrics from the validation split. |
| `known_weaknesses` | Honest list of failure modes, biases, and slices that underperform. |
| `recommended_thresholds` | Suggested per-class confidence thresholds. **Advisory only.** |
| `export_format` | `tflite`. |

### Canonical class order

Classes must be listed in exactly this order, matching
`ToyCategoryRegistry` and `ToyModelConfig.labels`:

```
0  toy_car
1  toy_truck
2  doll
3  stuffed_animal
4  building_blocks
5  ball
6  action_figure
7  toy_train
8  puzzle
9  board_game
10 not_toy
11 person
12 pet
13 book
14 unknown
```

Ignored / negative categories (never counted, regardless of detection
confidence) include: `person`, `pet`, `shoe`, `clothes`, `bottle`, `cup`,
`furniture`, `bed`, `pillow`, `phone`, `remote_control`, `book`, `unknown`.
See [class-taxonomy.md](class-taxonomy.md).

### `recommended_thresholds` — boundary rule

`recommended_thresholds` is **input to the business layer, not a decision**.

- The model record may suggest per-class thresholds based on
  precision/recall trade-offs observed in evaluation.
- The effective threshold used at runtime is owned by
  `ToyCategoryRegistry.minimumConfidence` per category, in the business layer.
- The model **never** decides whether a detection is acceptable, whether a
  toy is "real," whether to count it, or how to deduplicate it. Those live in
  `ToyDetectionRules`, `ToyTrackingEngine`, and `ToyCountingService`.
- Updating `ToyCategoryRegistry` to reflect a new model's thresholds is a
  **separate, deliberate** business-layer change, not an automatic import.

## Required cross-references

A version record must also link:

- [dataset-plan.md](dataset-plan.md) — the dataset spec the model was trained
  against, including any deviations.
- [training-pipeline.md](training-pipeline.md) — the exact pipeline,
  hyperparameters, and seeds used (for reproducibility).
- [evaluation-plan.md](evaluation-plan.md) — the gates the model was
  evaluated against, with pass/fail per gate.
- [export-to-tflite.md](export-to-tflite.md) — confirmation that the export
  matches the app's runtime contract (`assets/models/toy_detector.tflite`,
  input `[1, 320, 320, 3]` float, SSD-style outputs, `N = 25`).
- [privacy-rules.md](privacy-rules.md) — confirmation that no field-collected
  user images were used without consent and that no faces or child identifiers
  are in the training set.
- [known-risks.md](known-risks.md) — link any open risks that this version
  inherits or resolves.

## Naming and provenance

- `model_name` is stable across versions. Bumping `model_name` implies a
  fundamentally different architecture or task, not a retrain.
- `version` is bumped on **any** change that produces a different `.tflite`
  artifact — including dataset changes, hyperparameter changes, and
  quantization changes.
- Filename of the record matches `<model-name>-<version>.md` exactly.
- Records are immutable once promoted. Corrections require a new version.

## Audit rule — promotion to default

A model may **not** be promoted to the app's default detector unless **all**
of the following are true:

1. Its version record exists at
   `.toyvision/model-training/versions/<model-name>-<version>.md`.
2. Every required field above is present and non-empty.
3. The class list and order in the record exactly match
   `ToyCategoryRegistry` and `ToyModelConfig.labels`.
4. All accept gates in [evaluation-plan.md](evaluation-plan.md) **pass** and
   are linked from the record with their measured values.
5. Phase 2d physical-device QA has passed for this version on real hardware.
   (Currently blocked — no model is promotable today.)
6. [privacy-rules.md](privacy-rules.md) compliance is confirmed in the record.

Promotion is a deliberate change to the app's default
(`toyDetectorModeProvider`), made in a separate commit that cites the version
record. Until then, TFLite remains opt-in via fallback and `MockToyDetector`
stays the default. See [../ai-model-guidelines.md](../ai-model-guidelines.md).

## Rollback

- Previous version records remain on disk and are never deleted.
- Rolling back means re-pointing the app's default at the prior
  `<model-name>-<version>` whose record still passes the audit rule above.
- A rollback is itself a deliberate change, recorded in the commit that flips
  the default — not a silent swap.

## What this document does **not** define

- Final user-facing counts, certainty, or "is this a toy" decisions
  (business layer).
- Whether to display, ignore, or merge a detection (business layer).
- Whether to upload, store, or train on a frame — **never** by default; see
  [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md) and
  [privacy-rules.md](privacy-rules.md).
