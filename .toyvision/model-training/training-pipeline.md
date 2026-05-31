# Training Pipeline — ToyVision Toy Detector

This document is a **plan only**. No model is being trained in this phase.
`MockToyDetector` remains the default; the TFLite runtime is behind a fallback
and Phase 2d physical-device QA is **BLOCKED** (no Android device or emulator
available). Nothing here should be executed yet.

The detector only proposes boxes and labels. Final count, toy validity,
confidence acceptability, duplicate identity, and ignore behavior live in the
business layer (`ToyCategoryRegistry`, `ToyDetectionRules`,
`ToyTrackingEngine`, `ToyCountingService`) — never in the model. See
[../ai-model-guidelines.md](../ai-model-guidelines.md) and
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md).

## 1. Dataset folder structure (YOLO format)

```
datasets/toyvision/
  images/
    train/
    val/
    test/
  labels/
    train/
    val/
    test/
  data.yaml
```

- One label file per image, same stem (`img_0001.jpg` → `img_0001.txt`).
- Each label line: `class_index cx cy w h` (normalized 0..1, YOLO format).
- `class_index` must match the canonical class order in §7.
- See [dataset-plan.md](dataset-plan.md) for sourcing, consent, and splits.

## 2. data.yaml

Place at `datasets/toyvision/data.yaml`. Paths are placeholders — fill in at
training time; do not commit absolute machine paths.

```yaml
path: <ABSOLUTE_OR_RELATIVE_PATH_TO_datasets/toyvision>
train: images/train
val: images/val
test: images/test

# Canonical class order — must match ToyModelConfig.labels and
# ToyCategoryRegistry. See [class-taxonomy.md].
names:
  0: toy_car
  1: toy_truck
  2: doll
  3: stuffed_animal
  4: building_blocks
  5: ball
  6: action_figure
  7: toy_train
  8: puzzle
  9: board_game
  10: not_toy
  11: person
  12: pet
  13: book
  14: unknown
```

`person`, `pet`, `book`, `not_toy`, and `unknown` are present so the detector
learns to label them; the business layer ignores them and never counts them.

## 3. Recommended starting model

- **Variant:** small / nano YOLO — e.g. **YOLOv8n** or **YOLO11n**.
- **Library:** `ultralytics` **>= 8.3** (YOLO11 requires 8.3+; YOLOv8n works on
  any recent 8.x). Pin the exact version in the training environment lockfile
  and record it per [model-versioning.md](model-versioning.md).
- Rationale: nano variants are the only realistic target for on-device,
  real-time mobile inference at 320×320. Larger variants are out of scope until
  Phase 2d QA proves nano is insufficient.

## 4. Placeholder training command (do not run)

```bash
# Placeholder only — not executed in this phase.
yolo detect train \
  model=yolov8n.pt \
  data=datasets/toyvision/data.yaml \
  imgsz=320 \
  epochs=100 \
  batch=32 \
  project=runs/toyvision \
  name=v0
```

`imgsz=320` is **mandatory** — it matches `ToyModelConfig.inputWidth` and
`ToyModelConfig.inputHeight`. Changing the training input size requires a
corresponding `ToyModelConfig` change and a re-validation pass.

## 5. Placeholder validation command (do not run)

```bash
# Placeholder only — not executed in this phase.
yolo detect val \
  model=runs/toyvision/v0/weights/best.pt \
  data=datasets/toyvision/data.yaml \
  imgsz=320 \
  split=val
```

Test split is held out and only used once, just before promotion. mAP, per-class
recall, and latency targets are defined in
[evaluation-plan.md](evaluation-plan.md).

## 6. Placeholder export-to-TFLite command (do not run)

```bash
# Placeholder only — not executed in this phase.
yolo export \
  model=runs/toyvision/v0/weights/best.pt \
  format=tflite \
  imgsz=320 \
  int8=False \
  nms=True
```

The concrete TFLite output layout produced by the chosen exporter **must match**
what `TfliteTensorOutputParser` and `TfliteToyDetectorAdapter` expect, as
declared in `ToyModelConfig`:

- `boxesTensorIndex` → boxes `[1, N, 4]` in `[ymin, xmin, ymax, xmax]`.
- `classesTensorIndex` → classes `[1, N]`.
- `scoresTensorIndex` → scores `[1, N]`.
- `N = ToyModelConfig.maxDetections` (currently `25`).

If the exporter emits a different layout (e.g. transposed YOLO output, or
`[xmin, ymin, xmax, ymax]`, or a fused tensor), **only** these adapter-layer
components change:

- `ToyModelConfig` (tensor indices, box format flag).
- `TfliteTensorOutputParser` (parse + box-order normalization to `[ymin, xmin,
  ymax, xmax]`).
- `TfliteToyDetectorAdapter` (wiring).

The business layer (`ToyCategoryRegistry`, `ToyDetectionRules`,
`ToyTrackingEngine`, `ToyCountingService`) and `ToyDetector` contract **never**
change to accommodate an exporter quirk.

## 7. Class order mapping

Training class indices are the model's contract. They must match
`ToyModelConfig.labels` (the order is enforced by `ModelMetadataValidator` at
load time, which also checks every label is registry-known).

| Index | Label              | Counted? |
| ----- | ------------------ | -------- |
| 0     | `toy_car`          | yes      |
| 1     | `toy_truck`        | yes      |
| 2     | `doll`             | yes      |
| 3     | `stuffed_animal`   | yes      |
| 4     | `building_blocks`  | yes      |
| 5     | `ball`             | yes      |
| 6     | `action_figure`    | yes      |
| 7     | `toy_train`        | yes      |
| 8     | `puzzle`           | yes      |
| 9     | `board_game`       | yes      |
| 10    | `not_toy`          | no       |
| 11    | `person`           | no       |
| 12    | `pet`              | no       |
| 13    | `book`             | no       |
| 14    | `unknown`          | no       |

Additional ignored real-world categories (`shoe`, `clothes`, `bottle`, `cup`,
`furniture`, `bed`, `pillow`, `phone`, `remote_control`, …) are labeled as
`not_toy` at annotation time so the detector learns to suppress them; they are
not separate model classes. The business layer ignores them regardless.

Renaming, reordering, adding, or removing a class is a coordinated change:
dataset labels, `data.yaml`, `ToyModelConfig.labels`, `ToyCategoryRegistry`,
and the model file version must all update together.

## 8. Expected input

- Shape: `[1, 320, 320, 3]` float.
- Normalization: `(pixel - inputMean) / inputStd`, defaults `inputMean = 0`,
  `inputStd = 255` (i.e. `pixel / 255`).
- Single batch (`batch = 1`).
- Sensor-native orientation; no rotation is applied at this layer (rotation
  is a Phase 2c.2 / on-device concern — see
  [../ai-model-guidelines.md](../ai-model-guidelines.md)).

## 9. Expected output contract (SSD-style)

The TFLite model is expected to expose three output tensors:

- `boxes`   : `[1, N, 4]` float, `[ymin, xmin, ymax, xmax]`, normalized 0..1.
- `classes` : `[1, N]` float (or int), values in `0 .. len(labels) - 1`.
- `scores`  : `[1, N]` float, 0..1 confidence.
- `N = ToyModelConfig.maxDetections` (`25`).

Tensor indices are read from `ToyModelConfig.boxesTensorIndex /
classesTensorIndex / scoresTensorIndex`. The runtime returns raw detections to
the app in the common shape declared in
[../ai-model-guidelines.md#model-output-contract](../ai-model-guidelines.md):

```json
{
  "label": "toy_car",
  "confidence": 0.91,
  "box": { "x": 0.12, "y": 0.20, "width": 0.30, "height": 0.18 }
}
```

`MockToyDetector` already conforms to this shape; the TFLite path must remain
swap-compatible.

## 10. Pre-placement checklist

Before dropping a built file at `assets/models/toy_detector.tflite`, all of the
following must pass. Until every item is checked, the mock detector remains the
default and `toy_detector.tflite` is **not** committed.

- [ ] `ModelMetadataValidator` passes (label count and order match
      `ToyModelConfig.labels`; all labels registry-known).
- [ ] Tensor shapes match `TfliteTensorOutputParser` expectations
      (`boxes [1, N, 4]`, `classes [1, N]`, `scores [1, N]`,
      `N = maxDetections`, boxes are `[ymin, xmin, ymax, xmax]` after
      adapter normalization).
- [ ] Input shape is `[1, 320, 320, 3]` float with `pixel / 255`
      normalization.
- [ ] Class order verified against §7 and `ToyModelConfig.labels`.
- [ ] mAP and per-class recall meet thresholds in
      [evaluation-plan.md](evaluation-plan.md).
- [ ] On-device latency meets the budget in
      [evaluation-plan.md](evaluation-plan.md).
- [ ] Privacy review: no faces, no child identification, no person identity
      labels, no training on user images without consent
      ([../privacy-safety-guidelines.md](../privacy-safety-guidelines.md)).
- [ ] Version recorded per [model-versioning.md](model-versioning.md)
      (dataset snapshot, ultralytics version, training command, metrics,
      export command, hash of the exported file).
- [ ] Phase 2d physical-device QA executed and passed
      (currently **BLOCKED** — no device/emulator available).

Until every box above is checked, `toyDetectorModeProvider` stays on `mock` and
no `.tflite` is committed.

## Reiteration

No model is being trained in this phase. This document defines the pipeline so
that when training begins, the exported artifact will drop into the existing
TFLite runtime without forcing changes outside `ToyModelConfig`,
`TfliteTensorOutputParser`, and `TfliteToyDetectorAdapter`.
