# Custom Toy Detector — Strategy Reset (Phase 3.7)

This document is **governance**. It records the decision to stop relying on
generic open-source baselines (COCO SSD MobileNet, Google ML Kit Object
Detection's stock classifier) and commit to a **custom-trained toy detector**.

No model is trained in this phase. No code is changed. The `MockToyDetector`
remains the default and the fallback pattern stays. This document supersedes
the YOLO-first recommendation in
[training-pipeline.md](training-pipeline.md) §3 — that file should be
updated to track the path selected here when training actually begins.

Cross-references:

- [class-taxonomy.md](class-taxonomy.md) — canonical class list (binding).
- [dataset-plan.md](dataset-plan.md) — sourcing, splits, balance.
- [privacy-rules.md](privacy-rules.md) — non-negotiable privacy bar.
- [evaluation-plan.md](evaluation-plan.md) — accept gates.
- [export-to-tflite.md](export-to-tflite.md) — runtime contract.
- [../ai-model-guidelines.md](../ai-model-guidelines.md) — detector contract.
- [open-source-model-evaluation.md](open-source-model-evaluation.md) — the
  baseline evaluation that led to this reset.

## 1. Why the generic open-source baseline is insufficient

Phase 3.5 wired the COCO SSD MobileNet V1 quantized TFLite baseline. Phase 3.6
replaced it with Google ML Kit Object Detection. Both were chosen as
*validation* models for the live pipeline, never as the final detector. Both
fail the product bar for ToyVision-specific reasons:

| Baseline | Result on real toys | Failure mode |
| --- | --- | --- |
| COCO SSD MobileNet V1 (TFLite) | 0 useful detections on real toy scenes | All emitted boxes were class index 0 (background) with scores 0.07–0.16; boxes were near-identical frame-to-frame; preprocessing/uint8 reshape was brittle |
| ML Kit Object Detection (stock) | Detects objects but labels are 5 generic buckets (`Home good`, `Fashion good`, `Food`, `Place`, `Plant`) | Cannot distinguish `toy_car` from `book` from `bottle`; cannot identify `doll` / `stuffed_animal` / `building_blocks` etc. by name |

Beyond the immediate detection numbers, both baselines miss the **product
classes that matter** to ToyVision:

- COCO has no `doll`, `building_blocks`, `action_figure`, `toy_train`,
  `puzzle`, `board_game`.
- COCO `car`/`truck` are real-world vehicles; mapping them to `toy_car` /
  `toy_truck` is dishonest in production.
- ML Kit's five generic categories cannot meet a per-toy counting product.

**Conclusion:** no off-the-shelf generic model can satisfy the ToyVision
product goal of toy-specific live counting. A custom detector trained on
toys-only data is required.

## 2. Target ToyVision classes

The detector emits raw classes per [class-taxonomy.md](class-taxonomy.md).
This list is binding — changing it requires updating the registry in the
same change.

Toy classes (must count):

```text
toy_car
toy_truck
doll
stuffed_animal
building_blocks
ball
action_figure
toy_train
puzzle
board_game
```

Non-toy class the model is allowed to predict so the business layer can
explicitly drop it (instead of relying on `unknown` fallback):

```text
not_toy
```

Negative/ignored classes — the model SHOULD learn to predict these so the
business layer ignores them explicitly rather than confusing them with toys:

```text
person
pet
book
```

Total ordered class index list (must match `ToyCategoryRegistry` and the
exported model's label file):

```text
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
```

`unknown` is intentionally NOT in this list. It is a **business-layer
fallback** for any label outside the registry, not a class the model
predicts.

## 3. Training options compared

| Option | Framework | Training output | Mobile runtime | License (training tooling) | Notes |
| --- | --- | --- | --- | --- | --- |
| **A** | TensorFlow Lite Model Maker / Google AI Edge MediaPipe Model Maker | `.tflite` (EfficientDet Lite 0/1/2) | `tflite_flutter` or MediaPipe Tasks | Apache-2.0 | Successor to deprecated `tflite-model-maker` (2023). Designed for mobile object detection, ships pre-built EfficientDet Lite architectures. |
| **B** | MediaPipe Tasks (Object Detection) custom model | MediaPipe `.task` bundle wrapping TFLite | MediaPipe Tasks Android plugin | Apache-2.0 | Google AI Edge's mobile-first path. Same EfficientDet Lite backbone as A but bundled with metadata for the MediaPipe runtime. |
| **C** | Ultralytics YOLOv8 / YOLO11 nano | `.pt` + TFLite export | `tflite_flutter` or custom plugin | **AGPL-3.0** for code (and weights derivative) | Strong detection performance, fastest iteration loop. License blocks closed-source/commercial deployment without a paid Ultralytics license. |
| **D** | TensorFlow Object Detection API (TF1 legacy) | `.tflite` (SSD MobileNet variants) | `tflite_flutter` | Apache-2.0 | Older toolchain; documentation gaps; tensor layouts varied across exports — caused the Phase 3.5 baseline grief. |
| **E** | PyTorch torchvision (Faster R-CNN, RetinaNet) + ONNX → TFLite | `.tflite` after multi-step conversion | `tflite_flutter` | BSD/MIT-permissive | Maximum architectural flexibility, but multi-step export is fragile. |

A and B are effectively the same backbone (EfficientDet Lite) trained the
same way; they differ only in how the artifact is packaged and loaded on
device.

## 4. Licensing risks

The product must remain shippable under permissive terms. Each candidate is
evaluated on **training-tool licence**, **weights/architecture licence**,
**runtime plugin licence**, and **dataset licence**:

| Candidate | Training tool | Weights/architecture | Mobile runtime | Verdict |
| --- | --- | --- | --- | --- |
| A — TFLite Model Maker / MediaPipe Model Maker | Apache-2.0 | Apache-2.0 (EfficientDet Lite) | Apache-2.0 (`tflite_flutter`) or Apache-2.0 (MediaPipe Tasks) | ✅ Clear |
| B — MediaPipe Tasks custom OD | Apache-2.0 | Apache-2.0 | Apache-2.0 | ✅ Clear |
| C — Ultralytics YOLO | **AGPL-3.0** | AGPL-3.0 (Ultralytics treats weights as derivative work) | Plugin-dependent | ⚠️ **Blocked** for default-path use without a paid Ultralytics enterprise licence. Acceptable only in research/forks under matching open-source terms. |
| D — TF Object Detection API | Apache-2.0 | Apache-2.0 (MobileNet) | Apache-2.0 | ✅ Clear but tooling is legacy |
| E — PyTorch torchvision | BSD-3-Clause | Varies per model — most MIT/BSD | Plugin-dependent | ✅ Permissive but conversion path is fragile |

**Dataset licence** is treated separately in
[dataset-plan.md](dataset-plan.md) and [privacy-rules.md](privacy-rules.md).
Self-captured images of toys the project owns are the only fully
unencumbered source; any third-party dataset must have its licence reviewed
before inclusion.

## 5. Recommended training path

**Primary: Option A — Google AI Edge MediaPipe Model Maker (Object
Detection), EfficientDet Lite 0 backbone.**

Reasons:

1. **Apache-2.0 throughout.** Training tool, backbone, and mobile runtime
   are all permissive — no enterprise licence required.
2. **Designed for mobile.** EfficientDet Lite 0 targets phone-class GPUs/CPUs
   with float32 inputs at 320×320, producing TFLite outputs that match the
   SSD-style `[boxes, classes, scores, num_detections]` layout we already
   parse.
3. **Float32 input avoids the Phase 3.5 quantization-reshape brittleness.**
   `tflite_flutter`'s reshape works cleanly on `Float32List`; the uint8
   variant of the same backbone is the path that caused the silent-failure
   bug.
4. **Active maintenance.** `mediapipe-model-maker` superseded the now-
   deprecated `tflite-model-maker` in late 2023 and is the supported path
   for new training in 2026.

**Backup: Option B — MediaPipe Tasks Object Detector custom model.**

Same training pipeline, packaged as a `.task` bundle. Selected if A's
deployment via `tflite_flutter` proves fragile again — MediaPipe Tasks ships
with first-party preprocessing/orientation handling that does not rely on
the Flutter community's TFLite plugin.

**Explicitly avoided as default: Option C — Ultralytics YOLO.**

The AGPL-3.0 licence on Ultralytics' codebase and weights derivative makes
this path unsuitable for default product use. It remains acceptable for
internal research where the resulting work and its weights would be
published under matching open-source terms.

## 6. Recommended export format

Final on-device artifact:

```text
assets/models/toy_detector_v{semver}.tflite
```

Output tensor layout (must match
[export-to-tflite.md](export-to-tflite.md) §3):

| Index | Tensor | Shape | Dtype | Semantics |
| --- | --- | --- | --- | --- |
| 0 | boxes | `[1, N, 4]` | float32 | `[ymin, xmin, ymax, xmax]` normalized 0..1 |
| 1 | classes | `[1, N]` | float32 | Class indices rounded to int |
| 2 | scores | `[1, N]` | float32 | 0..1 |
| 3 | num_detections | `[1]` | float32 | Detected-count scalar |

`N` defaults to 25. The model file must include the canonical label order
from §2 as embedded metadata (`tflite_support` metadata writer) so the
runtime can fail-fast if the deployed model's classes diverge from
`ToyCategoryRegistry`.

Input layout:

| Property | Value |
| --- | --- |
| Shape | `[1, 320, 320, 3]` |
| Dtype | float32 |
| Normalization | `(pixel - 127.5) / 127.5` → [-1, 1] |

Phase 3.5's hard lesson — model-side quantization with `uint8` input — is
deliberately avoided. Float32 is ~4× the model size on disk (still under 20
MB for EfficientDet Lite 0) but bypasses the brittle reshape/quantization
quirks of the Flutter TFLite plugin.

## 7. Expected app integration path

The detector layer (`lib/detection/detectors/`) already supports the
strategy pattern, so the new custom model is added as a third detector
alongside `MockToyDetector` and `MlKitObjectDetector`:

```text
lib/detection/detectors/
  toy_detector.dart                  (interface — unchanged)
  mock_toy_detector.dart             (default, stays)
  fallback_toy_detector.dart         (wrapper, stays)
  mlkit/
    mlkit_object_detector.dart       (current ML Kit primary — stays as a fallback option)
  custom/                            (NEW in Phase 3.8)
    custom_toy_detector.dart         (loads the TFLite asset, runs inference)
    custom_toy_model_config.dart     (asset path, input/output contract)
    custom_label_map.dart            (re-confirms registry sync)
```

`ToyDetectorMode` gains a third value:

```dart
enum ToyDetectorMode { mock, mlkitWithFallback, customToyDetector }
```

Provider wiring routes `customToyDetector` through a `FallbackToyDetector`
that prefers the custom TFLite primary and falls back to ML Kit (and then to
mock) if model loading fails. The mode toggle on `DetectorModeChip` cycles
through all three (or a separate dev/QA picker exposes them; UX decided in
Phase 3.8).

Runtime dependency: `tflite_flutter` is re-introduced **with the fixes
applied during Phase 3.5**:

- Pre-allocate buffers for **every** output tensor index (the null-deref bug
  in `runForMultipleInputs`).
- Float32 input only (no uint8 reshape).
- Orientation wired via `lib/detection/geometry/` (`FrameOrientation`,
  `RotationTransform`) before going live.

No business-layer code changes are required.

## 8. Dataset requirements

Binding rules from [dataset-plan.md](dataset-plan.md) and
[privacy-rules.md](privacy-rules.md) hold without exception:

- **Self-captured only for the prototype dataset.** Any third-party dataset
  must pass licence + privacy review before inclusion.
- **No faces. No identifiable children. No private home details.** Even
  consenting adults must not appear identifiably; a child cannot
  meaningfully consent to training-data use of their image.
- **No raw images committed to this repository.** Dataset lives outside
  the repo; `.gitignore` blocks `datasets/` paths.
- **Per-image consent metadata required** for any image of a known person
  (e.g. the project owner's own hand in the frame as a scale reference).

Scene coverage required for the model to be reliable (matches the user's
brief and [dataset-plan.md](dataset-plan.md)):

- toys alone
- toys mixed together (occlusion, overlap)
- toys on floor (varied flooring textures)
- toys in boxes / containers
- toys on shelves
- toys partially hidden (occlusion at 25–75%)
- toys in low light
- toys in normal indoor light
- small toys (<5% of frame area)
- similar non-toy objects (real cars, real plush textures, books, bottles)
- background clutter (rooms in normal use)

Each toy class needs distribution across at least the lighting and
occlusion axes; classes underrepresented on any axis go on the next
collection pass before training.

## 9. Minimum dataset for prototype

A first trainable dataset to validate the pipeline end-to-end, not the
product:

| Metric | Target |
| --- | --- |
| Total images | **300–500** |
| Toy classes covered | All 10 (toys) + 3 ignored (person, pet, book) |
| Images per toy class | **20–35** |
| Images with multiple toys | At least 50 |
| Negative-only images (no toys) | At least 30 |
| Lighting variety | Indoor day + indoor night + ambient lamp light |
| Occlusion variety | 0–25%, 25–50%, 50–75% per toy class (at least 5 each) |
| Train/val/test split | 70 / 15 / 15 |

Goal at this dataset size: **trainable**, not **shippable**. The expected
prototype mAP@0.5 is in the 0.30–0.45 range — enough to prove the
end-to-end pipeline + runtime work on the device, not enough to ship.

## 10. Production dataset target

The bar for promoting the custom detector from prototype to default:

| Metric | Target |
| --- | --- |
| Total images | **3,000–5,000** |
| Toy classes covered | All 10 + 3 ignored |
| Images per toy class | **200–400** |
| Multi-toy images | At least 800 |
| Negative-only images | At least 400 |
| Lighting variety | ≥ 4 distinct sources covered per class |
| Occlusion variety | All buckets (0–75%) covered per class |
| Device variety | At least 3 Android devices for capture (S25 + 2 budget devices) |
| Train/val/test split | 70 / 15 / 15 with held-out unseen toys per class |

A held-out unseen-toy test slice is required to verify the model
generalizes beyond the exact toys it was trained on (a new doll, a
different stuffed bear, a different building set).

## 11. Evaluation gates

Defined in [evaluation-plan.md](evaluation-plan.md). The Phase 3.8 default
promotion gates for promoting the custom model from opt-in to default:

| Gate | Threshold |
| --- | --- |
| Overall mAP@0.5 on val | ≥ 0.65 |
| mAP@0.5 on held-out unseen toys | ≥ 0.45 |
| Per-class recall (all 10 toy classes) on val | ≥ 0.55 |
| Per-class precision (all 10 toy classes) on val | ≥ 0.55 |
| `person` recall (so the business layer can drop them reliably) | ≥ 0.70 |
| End-to-end on-device latency on Galaxy S25 (median) | ≤ 60 ms / frame |
| End-to-end on-device latency on Galaxy S25 (p95) | ≤ 120 ms / frame |
| False-positive rate on the no-toy test slice | ≤ 5% of frames |
| Frame loop never crashes during a 10-minute live session | required |

A model that does not meet **all** of these stays opt-in. The mock and
fallback paths remain available regardless.

## 12. What stays in business logic — never in the model

Per [../ai-model-guidelines.md](../ai-model-guidelines.md) and
[../business-logic-principles.md](../business-logic-principles.md), the
model is observation-only. It must not encode:

- the **final count** of toys → `ToyCountingService`
- whether a detection is a **real toy worth counting** →
  `ToyDetectionRules` + `ToyCategoryRegistry.countsAsToy`
- whether **confidence** is acceptable for the user →
  `ToyCategoryDefinition.minimumConfidence` per category
- **duplicate identity** across frames → `ToyTrackingEngine` (IoU + missing
  frame window)
- **ignored categories** (person, pet, book, food, plant, etc.) →
  `ToyCategoryRegistry.isIgnored`
- **stable-frames** thresholds before a toy counts →
  `RealtimeDetectionConfig.stableFramesToCount`

If a future model attempts to encode any of these — by emitting a
"final count" head, or by self-filtering its own outputs — the business
layer wins and the extra head is ignored. Detector contract from
[../ai-model-guidelines.md](../ai-model-guidelines.md) is binding.

## Implementation boundaries (this phase)

This phase is a strategy reset. It does **not**:

- delete the current ML Kit detector or its tests;
- delete the mock detector or the fallback path;
- change business / tracking / counting logic;
- flip TFLite or any custom model as the default mode;
- save frames, upload frames, or add any backend;
- train any model — see [training-pipeline.md](training-pipeline.md) for
  the future training-day plan, which itself stays unexecuted until the
  Phase 3.8 dataset gate is approved.

## Next phase

**Phase 3.8 — Custom toy detector prototype.** Sub-tasks (in order):

1. Stand up the prototype dataset (300–500 images) per §9.
2. Train EfficientDet Lite 0 via MediaPipe Model Maker on Colab/Python.
3. Export TFLite with the §6 contract; verify shapes match the
   `TfliteTensorOutputParser` expectations.
4. Re-introduce `tflite_flutter` with the Phase 3.5 lessons applied (pre-
   allocate every output buffer; float32 input only; orientation wired).
5. Add `lib/detection/detectors/custom/` with the new detector
   implementation and tests.
6. Wire `ToyDetectorMode.customToyDetector` and ship the chip toggle.
7. On-device QA on Galaxy S25; confirm the §11 evaluation gates are
   measured (even if not met) before changing the default.
8. Default stays `mock`. Custom model is opt-in. Promotion to default is a
   separate phase that depends on the production dataset of §10.
