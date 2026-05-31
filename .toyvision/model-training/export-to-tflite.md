# Export to TFLite — ToyVision Detector

Procedure for exporting the trained YOLO toy detector to TensorFlow Lite and
gating it before placement at `assets/models/toy_detector.tflite`. Commands here
are **documented, not executed**; no model file is committed by this doc.

Sibling docs:
[training-pipeline.md](training-pipeline.md),
[evaluation-plan.md](evaluation-plan.md),
[model-versioning.md](model-versioning.md).

## Why TFLite

- **On-device inference.** Frames never leave the phone — required by
  [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md).
- **No network dependency.** Detection runs offline; latency is bounded by the
  device, not the link.
- **Mobile-class runtime.** TFLite integrates with `tflite_flutter` behind the
  `ToyModelRuntime` seam (see [../ai-model-guidelines.md](../ai-model-guidelines.md)).
- **Small footprint.** A nano/small YOLO export keeps the asset shippable and
  the per-frame cost compatible with the realtime loop in
  [../realtime-detection-flow.md](../realtime-detection-flow.md).

## Status

- **Default detector remains `MockToyDetector`.** TFLite is opt-in via
  `ToyDetectorMode.tfliteWithFallback` and only activates after a valid model
  loads and its tensors validate.
- **Phase 2d physical-device QA is BLOCKED** (no Android device/emulator
  available). Latency, alignment, and orientation gates below cannot be
  declared passed until a real device is on hand.

## Export commands (documented, do not execute)

Assumes a trained YOLO checkpoint produced per
[training-pipeline.md](training-pipeline.md). Run from the training
environment, not from the app repo.

```bash
# 1. Export to TFLite at the production input resolution.
yolo export \
  model=runs/train/toyvision/weights/best.pt \
  format=tflite \
  imgsz=320 \
  int8=False \
  nms=True

# 2. (Optional) Float16 variant for size/latency trade-off review.
yolo export \
  model=runs/train/toyvision/weights/best.pt \
  format=tflite \
  imgsz=320 \
  half=True \
  nms=True

# 3. (Optional) INT8 quantized variant — requires a representative dataset.
yolo export \
  model=runs/train/toyvision/weights/best.pt \
  format=tflite \
  imgsz=320 \
  int8=True \
  data=datasets/toyvision/data.yaml \
  nms=True
```

The selected artifact will land at a path like
`runs/train/toyvision/weights/best_saved_model/best_float32.tflite`. Rename to
`toy_detector.tflite` only **after** the validation gates below pass.

## Validation gates

All five gates must pass before the file is placed at
`assets/models/toy_detector.tflite`. Failing any gate means **do not place the
model** — the default `MockToyDetector` stays in effect.

### Gate 1 — Tensor shape & SSD-style layout

Open the export in a TFLite inspector (e.g. Netron, `tflite_model_analyzer`).
Confirm:

| Tensor    | Expected shape       | Notes                              |
|-----------|----------------------|------------------------------------|
| input     | `[1, 320, 320, 3]` float | sensor-orientation RGB, normalized `(p - inputMean) / inputStd` |
| boxes     | `[1, N, 4]`          | `[ymin, xmin, ymax, xmax]` normalized |
| classes   | `[1, N]`             | integer class index per detection  |
| scores    | `[1, N]`             | float confidence per detection     |

`N = ToyModelConfig.maxDetections` (25). Indices for boxes/classes/scores must
match the values configured in `ToyModelConfig`.

### Gate 2 — `ModelMetadataValidator` passes

`ModelMetadataValidator` must accept the export against `ToyModelConfig`:

- `.tflite` asset path resolvable.
- Input shape, mean, std consistent with config.
- Output tensor count, shapes, and indices consistent with config.
- Class count matches `ToyModelConfig.labels.length`.

A validator failure surfaces as a load-time fallback to `MockToyDetector` —
that is the *runtime* safety net, **not** a substitute for clearing this gate
pre-placement.

### Gate 3 — Class order matches `ToyModelConfig.labels`

The mapped class order (model index 0..n) must match exactly:

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

Any registry-unknown label is treated as `unknown` and ignored by the business
layer (`ToyCategoryRegistry`, `ToyDetectionRules`). Ignored/negative classes
that must never be counted include: `person`, `pet`, `shoe`, `clothes`,
`bottle`, `cup`, `furniture`, `bed`, `pillow`, `phone`, `remote_control`,
`book`, `unknown`. If the trained label order diverges, **re-export or fix the
mapping** — do not patch in app code.

### Gate 4 — `TfliteToyModelRuntime` sanity run

Run a one-off harness against a sample image (a fixed, in-repo test fixture —
never a user image):

- Load the candidate `.tflite` via `TfliteToyModelRuntime` behind the
  `ToyModelRuntime` seam.
- Feed the preprocessed `[1,320,320,3]` float input.
- Confirm the adapter produces sensible `RawDetections`:
  - Box coordinates in `[0,1]` and ordered `ymin <= ymax`, `xmin <= xmax`.
  - Class indices within `[0, labels.length)`.
  - Scores in `[0,1]`, with at least one plausible high-score detection on the
    fixture.
  - Output count `<= maxDetections`.

The harness must **not** assert business outcomes (toy-ness, count,
acceptability). Those belong to `ToyDetectionRules`, `ToyTrackingEngine`, and
`ToyCountingService`.

### Gate 5 — Latency on a real Android device (Phase 2d)

On a representative Android device (not an emulator):

- Measure median and P95 per-frame inference time.
- Confirm the full realtime loop in
  [../realtime-detection-flow.md](../realtime-detection-flow.md) stays
  responsive at the target FPS.
- Confirm rotation/overlay alignment per the Phase 2c.2 items in
  [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md).

**This gate is currently BLOCKED** — no Android device/emulator is available.
Until it is exercised on real hardware, the export must not be promoted to
default, and any latency claim in release notes must read
*"pending physical-device QA"*.

## Failure handling

If **any** gate fails:

- Do **not** place the file at `assets/models/toy_detector.tflite`.
- Keep `toyDetectorModeProvider = mock`.
- File the failure against the export's version entry in
  [model-versioning.md](model-versioning.md) with the failing gate, the
  observed values, and the action taken (re-train, re-export, adjust config).

The runtime fallback (`FallbackToyDetector` reverting to `MockToyDetector` on
invalid models or mismatched shapes) is a backstop, not a pass condition.

## Versioning hook

Every export — even ones that fail a gate — must be recorded per
[model-versioning.md](model-versioning.md) **before** being used or promoted.
Record at minimum:

- Export timestamp and source checkpoint hash.
- Training dataset version (see [training-pipeline.md](training-pipeline.md)).
- Evaluation metrics (see [evaluation-plan.md](evaluation-plan.md)).
- Export flags (`imgsz`, quantization, `nms`).
- Gate results (1–5), including any "blocked" status for Gate 5.
- Class-order snapshot used at export time.

An unrecorded export must not be placed in `assets/models/` or referenced by
any build configuration.
