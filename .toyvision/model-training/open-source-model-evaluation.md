# Open-source Object Detection Model Evaluation

Phase 3.4 evaluation pass. **No model is trained or committed yet**, the mock
detector remains the default, and `tfliteWithFallback` still falls back to the
mock. The work in this phase is research + a controlled mapping prepared so
Phase 3.5 can wire a baseline TFLite model with one config switch.

## Status snapshot

- App validated on Galaxy S25 with mock detector (see
  [../manual-qa/phase-2a-camera.md](../manual-qa/phase-2a-camera.md)).
- TFLite runtime, preprocessing, parser, adapter, and fallback are in place.
- Geometry helpers exist but are not wired into production.
- No `.tflite` file in `assets/models/` — `RootBundleModelAssetLoader` returns a
  load failure, `TfliteToyDetector` throws `ModelUnavailableException`, and
  `FallbackToyDetector` switches to `MockToyDetector`. This is the safe state.

## Candidates considered

| Model | Source | License | Input | Output layout | TFLite ready |
|---|---|---|---|---|---|
| COCO SSD MobileNet V1 (int8) | TensorFlow Lite official | Apache-2.0 | 300x300x3 uint8 | SSD: boxes [1,N,4], classes [1,N], scores [1,N], num [1] | yes |
| COCO SSD MobileNet V2 | TF Hub / TF Model Maker | Apache-2.0 | 320x320 or 300x300 | Same SSD layout | yes |
| EfficientDet Lite0 | TF Hub / MediaPipe | Apache-2.0 | 320x320 | SSD-style boxes/classes/scores/num | yes |
| EfficientDet Lite1-4 | TF Hub / MediaPipe | Apache-2.0 | 384..512 | Same SSD layout | yes |
| YOLOv8n / YOLO11n (Ultralytics) | Ultralytics | **AGPL-3.0** + paid Enterprise | 320 or 640 | Single tensor `[1, 4+nc, anchors]` requiring NMS in code | yes via `yolo export` |
| MediaPipe Object Detector | Google MediaPipe | Apache-2.0 (underlying EffDet) | 320x320 | Wrapped; underlying model is EffDet Lite SSD-style | yes |

### Per-candidate notes

**COCO SSD MobileNet V1 (recommended baseline).** The classic TF Lite reference
model. Apache-2.0. ~4 MB int8. Output tensors map 1-for-1 to our existing
`TfliteTensorOutputParser` SSD layout — no parser changes needed. Input is
300x300; close enough to our default 320x320 that the nearest-neighbor resize
in `CameraImagePreprocessor.buildInputFromRgb` handles it cleanly when
`ToyModelConfig.inputWidth/Height` are set to 300.

**COCO SSD MobileNet V2.** Modern variant of the same family. Same Apache-2.0
license, same SSD output layout, typically 320x320 input. Slightly better
accuracy at similar latency. Drop-in replacement for V1 once we pick a
distribution channel that exposes a clean `.tflite` URL.

**EfficientDet Lite0.** Better accuracy than V1 SSD on COCO at comparable
latency. Same SSD-style output tensors, so parser is unchanged. Slightly larger
(~5 MB). Apache-2.0. A solid second choice if V1 underperforms on real toys.

**YOLOv8n / YOLO11n (Ultralytics).** Strong recent models, but licensed
**AGPL-3.0** which is copyleft. For a closed-source consumer app the Ultralytics
Enterprise License would be required (commercial fee). Output is a single
tensor `[1, 4+nc, anchors]` that needs NMS performed in code — would require
a new `TfliteToyDetectorAdapter` variant. **Not recommended as the baseline.**
Reconsider only when training a fully custom toy detector and the AGPL impact
is acceptable, or after switching to a non-AGPL fork.

**MediaPipe Object Detector.** Convenient packaging of EfficientDet Lite under
the MediaPipe runtime. Apache-2.0. Adds the `mediapipe_*` plugin dependency,
which is large and partially overlaps with what `tflite_flutter` already gives
us. The underlying `.tflite` can be loaded directly via `tflite_flutter` without
the MediaPipe runtime — preferred to keep the dependency surface small.

## License compatibility

| License | OK for closed-source product | Notes |
|---|---|---|
| Apache-2.0 | yes | Attribution required; permissive |
| AGPL-3.0 | no by default | Copyleft network/usage clauses; needs Ultralytics Enterprise to escape |
| MIT, BSD | yes | not encountered here, but commonly compatible |

ToyVision targets a consumer mobile app, so the baseline must be **Apache-2.0**.
That rules out Ultralytics YOLO for now and points us at the TF Lite SSD /
EfficientDet family.

## Recommended first integration target

**COCO SSD MobileNet V1 (Apache-2.0, ~4 MB int8).**

The chosen model does **not** need to detect toys accurately. Its only job in
Phase 3.5 is to prove the end-to-end real-inference path:

```
real camera frame → preprocessing → TFLite Interpreter →
  → tensor parsing → RawDetection → ToyDetectionRules →
  → ToyTrackingEngine → ToyCountingService → overlay
```

If that path runs cleanly on the Galaxy S25, we have a green-light to invest
in dataset collection and custom training (Phase 3.5+). If it doesn't, we have
something concrete to debug instead of two unknowns (preprocessing AND model
accuracy) at the same time.

## Class coverage analysis

COCO has 80 classes; ToyVision's `ToyCategoryRegistry` has 24 (11 toy + 13
ignored/negative). Realistic overlap when a COCO-trained model is pointed at a
play area:

| COCO class | ToyVision mapping | Confidence note |
|---|---|---|
| sports ball | ball | direct |
| teddy bear | stuffed_animal | direct |
| cell phone | phone | direct (registry: ignored) |
| remote | remote_control | direct (registry: ignored) |
| book | book | direct (registry: ignored) |
| bottle | bottle | direct (registry: ignored) |
| cup | cup | direct (registry: ignored) |
| bed | bed | direct (registry: ignored) |
| chair, couch, dining table, toilet, bench | furniture | grouped (registry: ignored) |
| backpack, handbag, tie, suitcase | clothes | loose (registry: ignored) |
| person | person | direct — **business layer drops** |
| cat, dog | pet | grouped — **business layer drops** |
| car | toy_car | **PROTOTYPE-ONLY** (see below) |
| truck | toy_truck | **PROTOTYPE-ONLY** (see below) |
| anything else | unknown | dropped by `ToyDetectionRules` |

So a COCO baseline can detect ~2 useful toy classes (`ball`, `stuffed_animal`)
with reasonable accuracy, plus 2 prototype-only mappings. The full ToyVision
class set — `doll`, `building_blocks`, `action_figure`, `toy_train`, `puzzle`,
`board_game` — **cannot** come from COCO. Those require a custom-trained model
(Phase 3.5+ dataset → train → export).

### Prototype-only mapping: car / truck

A COCO-trained model recognises real-size cars and trucks; it has no concept
of "toy" scale or context. Mapping `car → toy_car` silently would cause the app
to count actual cars seen through a window or in a TV scene as toys — exactly
the false-positive class we documented in
[dataset-plan.md](dataset-plan.md). The mapping is therefore tagged
**prototype-only**:

- Useful for verifying that boxes drawn over a toy car visually align with the
  preview and propagate through the count.
- Must NOT ship as a real product behaviour.
- Phase 3.5+ replaces this with a custom toy detector or, at minimum, a
  size/context filter in the business layer (a future Phase).

## Tensor layout compatibility

`TfliteTensorOutputParser` already expects the SSD layout the chosen baseline
emits:

- `boxes`  tensor index 0, shape `[1, N, 4]`, `[ymin, xmin, ymax, xmax]`
  normalised.
- `classes` tensor index 1, shape `[1, N]`, float indices.
- `scores`  tensor index 2, shape `[1, N]`, float in `[0, 1]`.

The classic TF Lite SSD MobileNet V1 also emits a `num_detections` tensor at
index 3 which we currently ignore (we already cap by `maxDetections`). No
parser change required.

## Parser / adapter changes for baseline integration

**None for COCO SSD MobileNet V1/V2 or EfficientDet Lite SSD-style output.**
Existing `TfliteTensorOutputParser` and `TfliteToyDetectorAdapter` work as-is.

If a future model uses YOLOv8-style output (`[1, 4+nc, anchors]` + in-code NMS)
we will add a sibling adapter (`YoloOutputAdapter`) and select it via config —
the business layer never changes.

## COCO → ToyVision mapping (this phase)

Phase 3.4 adds, in code:

- `CocoLabelMap` (constants): the 80 canonical COCO labels in model-output
  order, and a parallel list of the registry-known ToyVision label each COCO
  class maps to (unmatched → `'unknown'`).
- `CocoLabelMap.prototypeOnlyIndices`: indices whose mapping is unsafe in
  production (currently `{2 car, 7 truck}`).
- `CocoSsdToyModelConfig`: a const `ToyModelConfig` with `labels` already set
  to the ToyVision-mapped 80-entry list and `inputWidth/Height = 300`,
  `maxDetections = 10`. Validation is enabled through the relaxed validator
  flag because the mapped list contains many `'unknown'` entries by design.

Because `ToyModelConfig.labels[i]` is what `TfliteToyDetectorAdapter` reads,
this approach requires **no adapter changes** — the existing pipeline carries
COCO outputs through to the business layer with the correct ToyVision labels.

## Fallback strategy (already in place)

When the model file is absent or its shapes don't match, the existing chain
catches it:

- `RootBundleModelAssetLoader.load` throws → `TfliteToyDetector.initialize`
  throws `ModelUnavailableException` → `FallbackToyDetector` switches to the
  mock. Tests:
  [test/tflite_toy_detector_test.dart](../../test/tflite_toy_detector_test.dart),
  [test/fallback_toy_detector_test.dart](../../test/fallback_toy_detector_test.dart),
  [test/detector_mode_test.dart](../../test/detector_mode_test.dart).
- Shape mismatch at `load`: `TfliteTensorOutputParser.validateShapes` throws
  `TfliteRuntimeException` → caught by `TfliteToyModelRuntime.load` → bubbles
  to detector → fallback. Tests:
  [test/tflite_tensor_output_parser_test.dart](../../test/tflite_tensor_output_parser_test.dart),
  [test/tflite_toy_model_runtime_test.dart](../../test/tflite_toy_model_runtime_test.dart).
- Preprocessing / inference failure per frame: empty `TfliteModelOutput`
  returned, frame dropped, no crash.

No fallback work is required for Phase 3.4.

## Why this is a baseline, not the final model

- COCO contains only ~2 of the 11 ToyVision toy classes with usable accuracy.
- `car`/`truck` mappings are unsafe in production.
- Toy-specific shapes (doll, action figure, building blocks, train, puzzle,
  board game) are not in COCO at all.
- COCO accuracy on small / partially occluded / cluttered indoor toy scenes is
  significantly lower than on the validation distribution.

The baseline's value is **infrastructure validation**, not product accuracy.
Phase 3.5+ trains a custom toy detector against
[dataset-plan.md](dataset-plan.md) and
[collection-guide.md](collection-guide.md).

## Phase 3.5 wiring plan (next step, requires the model file)

1. Download the baseline model bundle (Apache-2.0):
   ```bash
   curl -L -o /tmp/coco_ssd.zip \
     https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip
   unzip /tmp/coco_ssd.zip -d /tmp/coco_ssd
   cp /tmp/coco_ssd/detect.tflite assets/models/toy_detector.tflite
   ```
2. Verify byte size (~4 MB) and license attribution in
   [assets/models/README.md](../../assets/models/README.md).
3. Wire the COCO config and a relaxed validator into the `tfliteWithFallback`
   path of `toyDetectorProvider`:
   ```dart
   case ToyDetectorMode.tfliteWithFallback:
     return FallbackToyDetector(
       primary: TfliteToyDetector(
         config: cocoSsdToyModelConfig,
         registry: ref.watch(toyCategoryRegistryProvider),
         validator: const ModelMetadataValidator(allowDuplicateLabels: true),
         runtime: TfliteToyModelRuntime(),
       ),
       fallback: MockToyDetector(),
     );
   ```
4. Keep `toyDetectorModeProvider` default = `ToyDetectorMode.mock`. TFLite is
   opt-in via UI (Phase 3.5 will add a toggle in a dev/settings surface, not
   live in production).
5. Run on Galaxy S25 and walk the manual QA in
   [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md):
   real boxes appear, business layer still drops people/pets, latency stays
   acceptable, pause/resume/reset still work, no crash, no media saved.
6. Promote to default only after a custom toy model exists and passes
   [evaluation-plan.md](evaluation-plan.md).

## Risks and open questions

- **Orientation.** The buffer is still in sensor orientation; with real
  detections any rotation mismatch will be visually obvious. Phase 2c.2
  helpers exist but are not wired. Wire them as soon as a real model lands.
- **Overlay alignment** under `BoxFit.cover` is still approximate. Same
  remediation path as above.
- **Latency** on a Galaxy S25 should be fine for SSD MobileNet (~30 ms typical),
  but on lower-end Android devices the existing throttle and skip-if-busy
  guards must keep the live loop healthy.
- **COCO label drift.** Some TF Lite distributions ship a 90-line labelmap
  (with `???` / N/A entries) instead of the canonical 80. `CocoLabelMap.cocoLabels`
  in this phase encodes the 80-class form. If a chosen distribution differs,
  swap the constants and the config — no other code changes.
- **car/truck false positives.** Documented as prototype-only; future product
  builds must replace COCO mapping with a custom toy detector before this can
  ever be a default.

## Decision

**Selected first model:** COCO SSD MobileNet V1 (Apache-2.0 int8 from the TF
Lite official bundle), staged behind `ToyDetectorMode.tfliteWithFallback`, with
the `CocoLabelMap`-based `ToyModelConfig` added in this phase. The model file
is **not** committed to the repository; Phase 3.5 places it locally per the
command above and runs the on-device validation.

**Recommendation after baseline runs once on the S25:** if the runtime path is
clean, **train a custom toy detector** against [dataset-plan.md](dataset-plan.md).
COCO is a stepping stone, not the destination.
