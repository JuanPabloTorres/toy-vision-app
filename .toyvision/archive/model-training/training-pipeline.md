# Training Pipeline — ToyVision Toy Detector

This document is a **plan only**. No model is being trained in this phase.
`MockToyDetector` remains the default. Phase 3.8 selects the concrete training
path; this file documents it.

**Path selected** (per
[custom-detector-strategy.md](custom-detector-strategy.md) §5):

- **Tool:** Google AI Edge **MediaPipe Model Maker** for Object Detection.
- **Architecture:** **EfficientDet Lite 0** (320×320, float32).
- **Export:** TFLite with embedded label metadata, SSD-style output layout
  (`boxes`, `classes`, `scores`, `num_detections`).
- **Mobile runtime:** `tflite_flutter` (reintroduced in Phase 3.8 with the
  Phase 3.5 lessons applied — pre-allocate every output buffer, float32 only,
  orientation wired before going live).
- **Avoided as default:** Ultralytics YOLO (AGPL-3.0 licence on both code and
  trained-weights derivative). See [custom-detector-strategy.md](custom-detector-strategy.md) §4.

The detector only proposes boxes and labels. Final count, toy validity,
confidence acceptability, duplicate identity, and ignore behavior live in the
business layer (`ToyCategoryRegistry`, `ToyDetectionRules`,
`ToyTrackingEngine`, `ToyCountingService`) — never in the model. See
[../ai-model-guidelines.md](../ai-model-guidelines.md) and
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md).

For step-by-step training instructions, see
[colab-training-plan.md](colab-training-plan.md). For the pre-training
quality bar, see
[dataset-validation-checklist.md](dataset-validation-checklist.md). For the
Flutter integration plan, see
[flutter-integration-plan.md](flutter-integration-plan.md).

## 1. Dataset folder structure (PASCAL VOC format)

MediaPipe Model Maker for Object Detection consumes PASCAL VOC XML
annotations (one `.xml` per image with `<object>` boxes in pixel
coordinates). This replaces the YOLO normalized-text format used by the
previous draft of this doc.

```
datasets/toyvision/
  train/
    images/
      img_0001.jpg
      img_0002.jpg
      ...
    annotations/
      img_0001.xml
      img_0002.xml
      ...
  val/
    images/
    annotations/
  test/
    images/
    annotations/
```

- One `.xml` per image, same stem.
- Each `<object>` has a `<name>` (class label string, must match §7) and a
  `<bndbox>` (`xmin`, `ymin`, `xmax`, `ymax` in pixels of the source image).
- Class label strings — not indices — are the contract. MediaPipe Model
  Maker assigns indices internally and embeds the ordered label list in the
  exported TFLite metadata; we read it back at model load time to verify
  it matches `ToyCategoryRegistry`.
- See [dataset-plan.md](dataset-plan.md) for sourcing, consent, and
  splits. See [dataset-validation-checklist.md](dataset-validation-checklist.md)
  for the pre-training quality bar.

## 2. Class label set

The model is trained on **14 labels** — the toy classes plus the negatives
the registry treats as ignored. `unknown` is NOT a model class; it is the
business-layer fallback for anything the model didn't predict.

```text
toy_car          (counted)
toy_truck        (counted)
doll             (counted)
stuffed_animal   (counted)
building_blocks  (counted)
ball             (counted)
action_figure    (counted)
toy_train        (counted)
puzzle           (counted)
board_game       (counted)
not_toy          (ignored — explicit non-toy)
person           (ignored)
pet              (ignored)
book             (ignored)
```

`person`, `pet`, `book`, and `not_toy` are present so the detector learns
to label them; the business layer ignores them and never counts them. The
binding class list lives in [class-taxonomy.md](class-taxonomy.md).

## 3. Recommended starting model

- **Variant:** **EfficientDet Lite 0** via Google AI Edge **MediaPipe Model
  Maker**.
- **Library:** `mediapipe-model-maker` (Apache-2.0). Pin the exact version
  in the Colab notebook header per
  [model-versioning.md](model-versioning.md).
- **Rationale:** EfficientDet Lite 0 is Google's mobile-class detector
  designed for ~30 ms inference on phone CPUs at 320×320. Float32 inputs
  avoid the uint8 reshape brittleness that broke the Phase 3.5 baseline.
  Apache-2.0 throughout — no enterprise licence required.

Upgrade path if Lite 0 plateaus on accuracy: Lite 1 (384×384) and Lite 2
(448×448), evaluated against the latency budget in
[evaluation-plan.md](evaluation-plan.md). All variants share the same
export contract, so app-side code does not change.

## 4. Training command (documented; executed only in Phase 3.8 Colab)

The training is performed in Python on Google Colab — never inside the
Flutter app. See [colab-training-plan.md](colab-training-plan.md) for the
notebook structure. Concrete command excerpt:

```python
# Documented; executed in Colab (Phase 3.8 prototype training).
from mediapipe_model_maker import object_detector

train_data = object_detector.Dataset.from_pascal_voc_folder(
    'datasets/toyvision/train',
    cache_dir='/tmp/od_cache_train',
)
val_data = object_detector.Dataset.from_pascal_voc_folder(
    'datasets/toyvision/val',
    cache_dir='/tmp/od_cache_val',
)

spec = object_detector.SupportedModels.EFFICIENTDET_LITE0
hparams = object_detector.HParams(
    learning_rate=0.3,
    batch_size=8,
    epochs=50,
    export_dir='/content/exported',
)
options = object_detector.ObjectDetectorOptions(
    supported_model=spec,
    hparams=hparams,
)
model = object_detector.ObjectDetector.create(
    train_data=train_data,
    validation_data=val_data,
    options=options,
)
```

Input resolution stays at the EfficientDet Lite 0 default (320×320). The
exported TFLite asset's input shape **must** be `[1, 320, 320, 3]` float32;
this is read back and enforced by `CustomToyModelConfig` at model load.

## 5. Validation step

MediaPipe Model Maker's `evaluate()` returns COCO-style mAP and per-class
metrics on the validation split. Run after training:

```python
metrics = model.evaluate(val_data)
print(metrics)
# Expected keys: AP, AP50, AP75, APs, APm, APl, ARmax1, ARmax10, ARmax100,
# plus per-class entries.
```

Targets are defined in [evaluation-plan.md](evaluation-plan.md) and the
default-promotion gates in
[custom-detector-strategy.md](custom-detector-strategy.md) §11. The test
split is held out and only used once, just before promoting from opt-in to
default.

## 6. Export to TFLite

```python
model.export_model('toy_detector_v0_1.tflite')
```

The exported file ships with **embedded label metadata** (the ordered class
list from §2). `CustomToyModelConfig` reads this metadata at load time and
fails-fast if the labels diverge from `ToyCategoryRegistry`.

Output tensor layout produced by MediaPipe Model Maker for
EfficientDet Lite 0 (SSD-style, 4 outputs):

- `boxes`    : `[1, N, 4]` float, `[ymin, xmin, ymax, xmax]`, normalized 0..1.
- `classes`  : `[1, N]` float, class indices rounded to int.
- `scores`   : `[1, N]` float, 0..1 confidence.
- `num_detections` : `[1]` float scalar.
- `N` = 25 (default `max_detections` hparam).

`CustomToyDetector` reintroduces `tflite_flutter` to call the model. The
runtime path applies the Phase 3.5 lessons (see
[custom-detector-strategy.md](custom-detector-strategy.md) §7):

- **Pre-allocate buffers for every output tensor index.** The Phase 3.5
  null-deref in `runForMultipleInputs` came from skipping output index 3
  (`num_detections`). The new `CustomToyDetector` allocates all four.
- **Float32 input only.** The uint8/quantized path is deliberately not
  shipped — it was the root cause of the Phase 3.5 silent failure.
- **Orientation wired** via `lib/detection/geometry/`
  (`FrameOrientation.quarterTurns`, `RotationTransform`) before the
  detector is enabled live.

If a future model exporter emits a different layout (transposed,
`[xmin, ymin, xmax, ymax]`, or a fused tensor), **only** the adapter-layer
components change:

- `CustomToyModelConfig` (tensor indices, box-order flag).
- `CustomToyDetectorAdapter` (parse + box-order normalization).

The business layer (`ToyCategoryRegistry`, `ToyDetectionRules`,
`ToyTrackingEngine`, `ToyCountingService`) and `ToyDetector` contract
**never** change to accommodate an exporter quirk.

## 7. Class label mapping

Training labels are the model's contract. The MediaPipe-exported TFLite
file embeds these labels in its metadata (ordered, one per class index).
`CustomToyModelConfig` reads the metadata at load time and fails-fast if
the labels diverge from `ToyCategoryRegistry`.

| Label              | Counted? |
| ------------------ | -------- |
| `toy_car`          | yes      |
| `toy_truck`        | yes      |
| `doll`             | yes      |
| `stuffed_animal`   | yes      |
| `building_blocks`  | yes      |
| `ball`             | yes      |
| `action_figure`    | yes      |
| `toy_train`        | yes      |
| `puzzle`           | yes      |
| `board_game`       | yes      |
| `not_toy`          | no       |
| `person`           | no       |
| `pet`              | no       |
| `book`             | no       |

Index assignment is performed by MediaPipe Model Maker at training time
(typically alphabetical, but always recorded in the exported metadata). The
app reads it back; it does **not** assume a specific ordering.

Additional ignored real-world categories (`shoe`, `clothes`, `bottle`,
`cup`, `furniture`, `bed`, `pillow`, `phone`, `remote_control`, …) are
labeled as `not_toy` at annotation time so the detector learns to suppress
them; they are not separate model classes. The business layer ignores them
regardless.

Renaming, adding, or removing a class is a coordinated change: dataset
annotations, `CustomToyModelConfig`, `ToyCategoryRegistry`, and the model
file version must all update together.

## 8. Expected input

- Shape: `[1, 320, 320, 3]` float32.
- Normalization: `(pixel - 127.5) / 127.5` → `[-1, 1]` (EfficientDet Lite
  default; verify against the exported metadata).
- Single batch (`batch = 1`).
- **Upright** orientation. The Flutter side applies the sensor-rotation
  correction via `lib/detection/geometry/` before handing the frame to the
  detector — the Phase 3.5 sensor-orientation oversight is not repeated.

## 9. Expected output contract (SSD-style)

Four output tensors:

- `boxes`           : `[1, N, 4]` float, `[ymin, xmin, ymax, xmax]`, normalized 0..1.
- `classes`         : `[1, N]` float, class indices rounded to int.
- `scores`          : `[1, N]` float, 0..1.
- `num_detections`  : `[1]` float scalar — even though we may parse all N
                      rows and let the score floor handle it, **the buffer
                      must still be allocated** (Phase 3.5 lesson:
                      `runForMultipleInputs` null-derefs if any output index
                      lacks a buffer).
- `N = CustomToyModelConfig.maxDetections` (default `25`).

The runtime returns raw detections in the common app shape:

```json
{
  "label": "toy_car",
  "confidence": 0.91,
  "box": { "x": 0.12, "y": 0.20, "width": 0.30, "height": 0.18 }
}
```

`MockToyDetector` and `MlKitObjectDetector` already conform; the custom
path must too.

## 10. Pre-placement checklist

Before dropping the built file at
`assets/models/toy_detector_v{semver}.tflite`, all of the following must
pass. Until every item is checked, the default detector stays `mock` and no
`.tflite` is committed.

- [ ] Tensor shapes match the §9 contract (`boxes [1, N, 4]`,
      `classes [1, N]`, `scores [1, N]`, `num_detections [1]`).
- [ ] Input shape is `[1, 320, 320, 3]` float32 with `(p - 127.5) / 127.5`
      normalization.
- [ ] Embedded label metadata matches `ToyCategoryRegistry` and §7.
- [ ] mAP and per-class metrics meet thresholds in
      [evaluation-plan.md](evaluation-plan.md) and
      [custom-detector-strategy.md](custom-detector-strategy.md) §11.
- [ ] On-device latency on Galaxy S25 meets the budget in
      [evaluation-plan.md](evaluation-plan.md) (median ≤ 60 ms, p95 ≤ 120 ms).
- [ ] Privacy review: no faces, no child identification, no person
      identity labels, no training on user images without consent
      ([../privacy-safety-guidelines.md](../privacy-safety-guidelines.md)).
- [ ] Version recorded per [model-versioning.md](model-versioning.md):
      dataset snapshot, `mediapipe-model-maker` version pinned, training
      hparams, metrics, export hash.
- [ ] Sensor-orientation rotation is wired in the Flutter preprocessor
      before the detector is enabled live (do not repeat the Phase 3.5
      orientation oversight).

Until every box above is checked, `toyDetectorModeProvider` stays on `mock`
and the custom detector remains opt-in via the chip toggle.

## Reiteration

No model is being trained in this document; this file defines the pipeline.
Training execution happens in Colab per
[colab-training-plan.md](colab-training-plan.md). Dataset gating happens
per [dataset-validation-checklist.md](dataset-validation-checklist.md). App
integration happens per
[flutter-integration-plan.md](flutter-integration-plan.md).
