# Flutter Integration Plan — Custom Toy Detector (Phase 3.8 app side)

How the app side reintroduces TFLite-backed inference once Phase 3.8
produces a validated `toy_detector_v0_1.tflite` artifact. This document
defines **what** code lands and **where**, but does not write the code —
no Dart files are added in Phase 3.8 until the artifact exists and clears
the gates in [export-to-tflite.md](export-to-tflite.md).

Cross-references:

- [custom-detector-strategy.md](custom-detector-strategy.md) — integration
  shape (§7) and what stays in the business layer (§12).
- [training-pipeline.md](training-pipeline.md) — input/output contract
  (§8, §9, §10).
- [export-to-tflite.md](export-to-tflite.md) — pre-placement gates.
- [../ai-model-guidelines.md](../ai-model-guidelines.md) — detector
  contract and mock-first policy.

## What stays as-is

The refactor is **additive**. Nothing in the following list changes shape
for Phase 3.8:

- `lib/detection/detectors/toy_detector.dart` — strategy interface.
- `lib/detection/detectors/mock_toy_detector.dart` — default detector.
- `lib/detection/detectors/fallback_toy_detector.dart` — wrapper.
- `lib/detection/detectors/mlkit/mlkit_object_detector.dart` — current ML
  Kit primary; kept for the Phase 3.6 toggle path. May be deleted in a
  later phase once the custom detector reaches default-promotion, not
  now.
- `lib/business/*` — registry, rules, counting, state.
- `lib/tracking/*` — tracking engine.
- `lib/camera/*` — camera service, frame processing, controller.
- `lib/ui/*` — overlay, panels, components.
- `assets/models/` — empty during Phase 3.7; the `.tflite` lands here
  only after [export-to-tflite.md](export-to-tflite.md) gates pass.

## What is added

### Directory: `lib/detection/detectors/custom/`

```
lib/detection/detectors/custom/
  custom_toy_detector.dart            (implements ToyDetector)
  custom_toy_model_config.dart        (asset path, input/output contract, label set)
  custom_toy_label_map.dart           (registry sync + display names)
  custom_toy_detector_adapter.dart    (raw output tensors → RawDetection)
  custom_toy_model_runtime.dart       (loads model, runs inference, parses tensors)
  custom_tflite_interpreter_factory.dart (the ONLY tflite_flutter import seam)
  custom_camera_image_preprocessor.dart  (YUV420/BGRA8888 → upright RGB → float32 tensor)
  custom_model_metadata_validator.dart  (reads embedded labels, checks registry sync)
```

These mirror the Phase 3.5 structure but with the Phase 3.5 lessons baked
in (see "Lessons applied" below). Test files mirror the source tree:

```
test/custom/
  custom_toy_detector_test.dart
  custom_toy_detector_adapter_test.dart
  custom_toy_label_map_test.dart
  custom_model_metadata_validator_test.dart
  custom_camera_image_preprocessor_test.dart
  custom_tflite_tensor_output_parser_test.dart
```

### Provider wiring

In `lib/camera/live_detection_controller.dart`:

```dart
enum ToyDetectorMode { mock, mlkitWithFallback, customToyDetector }
```

`toyDetectorProvider` gains a third branch that returns a
`FallbackToyDetector` whose primary is `CustomToyDetector` and whose
fallback is the mock. Toggle order in
`ToyDetectorModeController.toggle()`:

```text
mock → mlkitWithFallback → customToyDetector → mock
```

`DetectorModeChip` cycles through all three and shows the active label.

### Default detector

`ToyDetectorMode.mock` remains the default. The custom detector is
opt-in via the chip until **all** gates in
[custom-detector-strategy.md](custom-detector-strategy.md) §11 pass and
the production dataset of §10 has been collected. Promotion to default
is a separate phase, not Phase 3.8.

### Asset bundling

In `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/models/
```

The `assets/models/` directory holds the validated TFLite file at the
path declared in `CustomToyModelConfig.assetPath`
(`assets/models/toy_detector_v0_1.tflite`).

### Dependencies

In `pubspec.yaml`:

```yaml
dependencies:
  ...
  # Reintroduced in Phase 3.8 to run the custom toy detector model. The
  # Phase 3.5 lessons are encoded in the new wrapper code (see custom/).
  tflite_flutter: ^0.11.0
  # Kept from Phase 3.6 for the mlkitWithFallback mode.
  google_mlkit_object_detection: ^0.14.0
```

Pin `tflite_flutter` to whatever version the Phase 3.8 prototype builds
and tests against. Do not auto-upgrade.

## Phase 3.5 lessons applied

These are the bugs that broke the Phase 3.5 baseline. The Phase 3.8
custom path explicitly does not repeat them.

### 1. Pre-allocate every output tensor buffer

The exported EfficientDet Lite 0 model has **4 output tensors**:
`boxes`, `classes`, `scores`, `num_detections`. The Phase 3.5 parser
only allocated buffers for the first 3 because the parser only consumed
3. `tflite_flutter` 0.11's `runForMultipleInputs` null-derefs when any
output index in `[0, outputTensors.length)` is missing from the buffer
map — even if the parser never reads it.

`custom_tflite_interpreter_factory.dart` ensures **every** output
tensor index has a zero-filled buffer matching its shape, then runs
inference. Optional outputs (`num_detections`) get an allocated buffer
that's never read. The Phase 3.5 fix is the reference implementation —
keep that defensive code.

### 2. Float32 inputs only

The Phase 3.5 quantized model used `uint8` input with a `Uint8List`
reshape path. `Uint8List.reshape()` produces a nested `List<int>` that
`tflite_flutter` accepts at the API surface but does not always
populate the tensor correctly. The Phase 3.5 result was a model that
saw effectively constant input every frame.

`custom_camera_image_preprocessor.dart` outputs a **`Float32List`** only.
Normalization is `(pixel - 127.5) / 127.5` per
[training-pipeline.md](training-pipeline.md) §8. The uint8 branch from
the Phase 3.5 preprocessor is **not** reintroduced; future quantized
variants are explicitly out of scope until the float32 path ships.

### 3. Orientation wired at the preprocessor

The Phase 3.5 preprocessor handed the model frames in the camera
sensor's native orientation — landscape on most Android phones. COCO
SSD MobileNet, trained on upright images, saw rotated input and never
detected anything. The Phase 2c.2 geometry helpers
(`lib/detection/geometry/FrameOrientation`,
`lib/detection/geometry/RotationTransform`) already exist; they were
never wired into the production preprocessor.

`custom_camera_image_preprocessor.dart` **uses** those helpers before
handing the frame to the interpreter. The exact rotation comes from
the active `CameraDescription.sensorOrientation`. A unit test on a
synthetic upright-vs-rotated fixture verifies the preprocessor does
not regress on this.

### 4. Surface inference errors in debug mode

The Phase 3.5 runtime swallowed every exception from
`Interpreter.runForMultipleInputs` and returned an empty output. The
silent failure delayed diagnosis by several iterations.

`custom_toy_model_runtime.dart` retains the catch (the live loop must
not crash on a transient runtime error) but emits a
`DetectionDiagnostics` line on the first failure per session and on
every Nth subsequent failure. Tests assert that the catch runs
quietly in production builds and verbosely in debug builds.

### 5. Mode toggle stops the camera stream first

The Phase 3.5 / 3.6 mode toggle had a race where the new detector
received a frame before its `initialize()` finished. Phase 3.6 patched
the controller's `processIncomingFrame` to guard on
`state.status != ready` — keep that guard. The custom detector mode
adds nothing new here, but the new `_init` path **must** await
`detector.initialize()` before resuming the stream, and the test in
`detector_mode_test.dart` is extended to cover the three-mode toggle
cycle.

## ToyDetector contract — unchanged

`CustomToyDetector.detect(DetectionFrame frame)` returns
`List<RawDetection>` exactly like `MockToyDetector` and
`MlKitObjectDetector`. The business layer downstream
(`ToyDetectionRules.validate`, `ToyTrackingEngine.update`,
`ToyCountingService.update`) does not change shape.

The detector emits raw detections only:

- `label` — one of the 14 canonical class strings.
- `confidence` — `[0, 1]`.
- `box` — `BoundingBox(x, y, width, height)` normalized `[0, 1]` in
  upright orientation (the preprocessor handled rotation already).

`isVisible`, `isStable`, "counted vs ignored", per-category confidence
thresholds — all stay in the business layer. The model does not
decide any of these. See
[custom-detector-strategy.md](custom-detector-strategy.md) §12.

## Diagnostics

`DetectionDiagnostics` (debug-only) gains a `customToyDetector` snapshot
that mirrors the existing per-frame line:

```
ToyVisionDX: mode=customToyDetector usingFallback=false
ToyVisionDX: custom.model=toy_detector_v0_1 inputShape=[1,320,320,3] outputs=[boxes,classes,scores,num_detections]
ToyVisionDX: detectorRaw=8 validated=3 rejects={low_confidence: 4, ignored: 1}
ToyVisionDX: top raw (sorted by confidence):
  [0] label="stuffed_animal" conf=0.78 box=[x=0.31,y=0.42,w=0.18,h=0.20]
  [1] label="toy_car"        conf=0.61 box=[x=0.12,y=0.66,w=0.14,h=0.10]
  ...
```

Throttled to 1 Hz like the existing line.

## Tests

| File | What it covers |
| --- | --- |
| `test/custom/custom_toy_detector_test.dart` | Full detector lifecycle: init, detect, dispose, fallback on missing asset. |
| `test/custom/custom_toy_detector_adapter_test.dart` | Tensor → `RawDetection` shape, box order, clamping. |
| `test/custom/custom_toy_label_map_test.dart` | Every label in the metadata is registered; ordering matches the registry. |
| `test/custom/custom_model_metadata_validator_test.dart` | Embedded label list parsed correctly; reject on mismatch. |
| `test/custom/custom_camera_image_preprocessor_test.dart` | Float32 output, `(p-127.5)/127.5` normalization, orientation rotation correct, shape `[1,320,320,3]`. |
| `test/custom/custom_tflite_tensor_output_parser_test.dart` | Pre-allocates every output buffer; null-deref regression test. |
| `test/detector_mode_test.dart` | Three-mode toggle cycle; default is still `mock`. |

The `tflite_flutter` native plugin is not available in `flutter test`;
the runtime is faked via the `TfliteInterpreterFactory` seam (same
pattern as the Phase 3.5 tests, which can serve as templates if
restored from `git log`).

## What stays out of Phase 3.8

- **Promoting the custom detector to default.** Default-promotion is
  gated on the production dataset (3,000–5,000 images) and the
  [custom-detector-strategy.md](custom-detector-strategy.md) §11 gates.
- **INT8 / quantized variants.** Out of scope until the float32 path
  ships and a latency win is demonstrated.
- **Removing the ML Kit detector.** Kept until the custom path proves
  itself; deleting working code prematurely is a worse mistake than
  carrying an extra mode.
- **Custom training inside the app.** The app never trains. Training is
  always Colab + downloaded artifact.
- **Saving frames or telemetry.** No frame, no annotation, no detection
  blob ever leaves the device. The `developer.log` diagnostics line is
  text only.

## Order of operations for Phase 3.8

1. Phase 3.7 strategy doc approved → ✅ (this happened).
2. Dataset collection runs per
   [dataset-plan.md](dataset-plan.md) and
   [dataset-validation-checklist.md](dataset-validation-checklist.md).
3. Privacy review signed off by the project owner.
4. Colab training run per [colab-training-plan.md](colab-training-plan.md).
5. Export gates per [export-to-tflite.md](export-to-tflite.md) cleared.
6. **Then** the Dart files in this plan are written and tested.
7. Custom detector ships as **opt-in** via the chip.
8. On-device QA on Galaxy S25 collects measurements against the §11
   strategy gates — as data, not as a promotion decision.
9. Default-promotion is a separate later phase.

Until step 5 produces a placed `.tflite`, no Dart code from this plan
is written and no `pubspec.yaml` change is committed. Phase 3.8 is
**strategy + dataset + training**, not app rewiring on speculation.
