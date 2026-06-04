# Export to TFLite — ToyVision Custom Toy Detector

Procedure for exporting the trained EfficientDet Lite 0 toy detector to
TensorFlow Lite and gating it before placement at
`assets/models/toy_detector_v{semver}.tflite`. Commands here are
**documented, not executed in the app repo** — training and export happen
on Colab per [colab-training-plan.md](colab-training-plan.md). No model
file is committed by this document.

This document supersedes the Phase 2b/3.5 YOLO-export draft. Selection
rationale lives in
[custom-detector-strategy.md](custom-detector-strategy.md).

Sibling docs:

- [training-pipeline.md](training-pipeline.md)
- [colab-training-plan.md](colab-training-plan.md)
- [dataset-validation-checklist.md](dataset-validation-checklist.md)
- [flutter-integration-plan.md](flutter-integration-plan.md)
- [evaluation-plan.md](evaluation-plan.md)
- [model-versioning.md](model-versioning.md)

## Why TFLite

- **On-device inference.** Frames never leave the phone — required by
  [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md).
- **No network dependency.** Detection runs offline; latency is bounded by
  the device, not the link.
- **Mobile-class runtime.** TFLite integrates with `tflite_flutter` (to be
  reintroduced in Phase 3.8) behind the `ToyDetector` strategy interface.
- **Small footprint.** EfficientDet Lite 0 float32 exports at roughly 16–20
  MB — shippable in an asset bundle and compatible with the realtime loop
  in [../realtime-detection-flow.md](../realtime-detection-flow.md).

## Status

- **Default detector remains `MockToyDetector`.** The custom TFLite path
  is opt-in via `ToyDetectorMode.customToyDetector` and activates only
  after the §"Validation gates" below are cleared.
- **Phase 3.8 prototype** is the immediate target — a trainable artifact,
  not a shippable one. Promotion to default requires the production
  dataset and the gates in
  [custom-detector-strategy.md](custom-detector-strategy.md) §11.

## Export command (documented; executed only in Colab)

Assumes a trained MediaPipe Model Maker object detector per
[colab-training-plan.md](colab-training-plan.md). Run from Colab, not from
the app repo.

```python
# Export the trained model to TFLite with embedded label metadata.
# Documented; executed in the Phase 3.8 training notebook.
model.export_model('toy_detector_v0_1.tflite')
```

That single `export_model()` call produces the TFLite file under the
notebook's `export_dir` (typically `/content/exported/`). MediaPipe Model
Maker writes the label list, normalization parameters, and tensor metadata
into the file using `tflite_support`'s metadata writer — there is no
separate post-export step required.

Download the file from Colab and hash it for the version record before
placing it in the app repo (see [model-versioning.md](model-versioning.md)).

## Float32 only — quantization is OUT

The Phase 3.5 baseline failure was caused in part by a uint8/quantized
model and a brittle reshape path in the Flutter TFLite plugin. The
prototype custom detector ships **float32 only**. INT8/quantized variants
are not pursued until:

1. The float32 path is proven end-to-end on real device.
2. A representative calibration dataset is collected.
3. A measured latency win justifies the quantization complexity.

This is a deliberate trade — ~16 MB instead of ~4 MB — to avoid the class
of silent failures we already paid for.

## Validation gates

All gates must pass before the file is placed at
`assets/models/toy_detector_v{semver}.tflite`. Failing any gate means **do
not place the model** — the default `MockToyDetector` stays in effect and
the custom detector mode is unwired.

### Gate 1 — Tensor shape & SSD-style layout

Open the export in a TFLite inspector (Netron, `tflite_support.metadata`)
and confirm:

| Tensor | Shape and dtype | Notes |
| --- | --- | --- |
| input | `[1, 320, 320, 3]` float32 | upright RGB, normalized `(p - 127.5) / 127.5` |
| boxes | `[1, N, 4]` float32 | `[ymin, xmin, ymax, xmax]` normalized |
| classes | `[1, N]` float32 | class index per detection |
| scores | `[1, N]` float32 | confidence per detection |
| num_detections | `[1]` float32 | detected-count scalar |

`N` = `CustomToyModelConfig.maxDetections` (default `25`).

**All four outputs must be present.** Even though the parser may iterate
all N rows and filter by score, `tflite_flutter`'s
`runForMultipleInputs` null-derefs if any output index lacks an
allocated buffer. The Phase 3.5 lesson is encoded in
`CustomToyDetector`'s buffer allocation.

### Gate 2 — Embedded metadata matches the registry

`CustomToyModelConfig.loadFromAssetMetadata` reads the embedded label
list and verifies:

- Label count equals the model's class count.
- Every label is registry-known (`ToyCategoryRegistry.isKnown`).
- Input mean/std match the expected `(127.5, 127.5)`.

A metadata mismatch surfaces as a load-time fallback (`FallbackToyDetector`
reverts to mock). That fallback is a **runtime safety net**, not a
substitute for clearing this gate pre-placement.

### Gate 3 — Class label set matches the canonical list

The embedded label list must equal the set in
[training-pipeline.md](training-pipeline.md) §7 — exactly, no extras, no
missing:

```text
toy_car, toy_truck, doll, stuffed_animal, building_blocks, ball,
action_figure, toy_train, puzzle, board_game, not_toy, person, pet, book
```

Index ordering is assigned by MediaPipe Model Maker at training time and
read from the metadata. `unknown` is intentionally absent — it's a
business-layer fallback, not a model class.

### Gate 4 — `CustomToyDetector` sanity run

Run a one-off harness against a sample image (a fixed, in-repo test
fixture — never a user image, never a child's image):

- Load the candidate `.tflite` via `CustomToyDetector`.
- Feed the preprocessed `[1, 320, 320, 3]` float32 input.
- Confirm the adapter produces sensible `RawDetections`:
  - Box coordinates in `[0, 1]` with `ymin <= ymax`, `xmin <= xmax`.
  - Class indices within `[0, labels.length)`.
  - Scores in `[0, 1]`, with at least one plausible high-score detection
    on the fixture.
  - Output count `<= maxDetections`.

The harness must **not** assert business outcomes (toy-ness, count,
acceptability). Those belong to `ToyDetectionRules`, `ToyTrackingEngine`,
and `ToyCountingService`.

### Gate 5 — On-device latency on Galaxy S25

On the project's reference device (Galaxy S25, Android 16, RFCY2244PCJ):

- Measure median and p95 per-frame inference time.
- Confirm the full realtime loop in
  [../realtime-detection-flow.md](../realtime-detection-flow.md) stays
  responsive at the target FPS.
- Confirm rotation/overlay alignment per the Phase 2c.2 items wired in
  the new `CustomToyDetector` preprocessing path.

Targets:

| Metric | Threshold |
| --- | --- |
| Median per-frame inference time | ≤ 60 ms |
| p95 per-frame inference time | ≤ 120 ms |
| Crash-free 10-minute live session | required |

### Gate 6 — Evaluation metrics meet the strategy thresholds

Per [custom-detector-strategy.md](custom-detector-strategy.md) §11:

- Overall mAP@0.5 on val ≥ 0.65 *(production default-promotion)*.
- Per-class precision AND recall on every toy class ≥ 0.55.
- `person` recall ≥ 0.70 so the business layer drops them reliably.
- No-toy slice false-positive rate ≤ 5%.

A prototype model below these thresholds is allowed to ship as opt-in for
QA, but **not** as the default detector.

### Gate 7 — Privacy review

Per [privacy-rules.md](privacy-rules.md) and
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md):

- No identifiable faces in training images.
- No children in training images, period.
- No private home details (mail, screens, addresses) in training images.
- No image uploaded to a third party without per-image consent metadata.
- No private images committed to this repo (`.gitignore` blocks
  `datasets/`).

Reviewed and approved by the project owner before the export is hashed and
recorded.

## Failure handling

If **any** gate fails:

- Do **not** place the file at `assets/models/`.
- Keep `toyDetectorModeProvider = mock` as the default.
- File the failure against the export's version entry in
  [model-versioning.md](model-versioning.md) with the failing gate, the
  observed value, and the action taken (re-train, re-export, adjust
  config, collect more data).

The runtime fallback (`FallbackToyDetector` reverting to `mock` on invalid
models) is a backstop, not a pass condition.

## Versioning hook

Every export — even ones that fail a gate — must be recorded per
[model-versioning.md](model-versioning.md) **before** being used or
promoted. Record at minimum:

- Export timestamp and source notebook hash.
- Training dataset version snapshot.
- `mediapipe-model-maker` version pinned in the notebook.
- Training hparams (learning rate, batch size, epochs, seed).
- Evaluation metrics on the validation split.
- Embedded label list as read back from the exported metadata.
- Gate results 1–7 with observed values for each.
- SHA-256 of the `.tflite` artifact.

An unrecorded export must not be placed in `assets/models/` or referenced
by any build configuration.
