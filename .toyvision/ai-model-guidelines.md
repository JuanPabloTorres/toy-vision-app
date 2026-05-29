# AI Model Guidelines — ToyVision Real-Time

The model is a **detector**, not the business decision-maker. It proposes; the Business
Logic Layer disposes.

## Phase rule

The MVP **must** begin with `MockToyDetector`. Only after the camera, overlay, tracking,
and counting work correctly — and pass tests — may the real model be connected via
`TfliteToyDetector` (wrapped by `TfliteToyDetectorAdapter`).

## Model direction

- YOLO-based detector.
- TensorFlow Lite export.
- Local, on-device inference.
- Start with a small / nano model variant.

## Model output contract

The detector returns raw detections in normalized coordinates:

```json
{
  "label": "toy_car",
  "confidence": 0.91,
  "box": { "x": 0.12, "y": 0.20, "width": 0.30, "height": 0.18 }
}
```

`MockToyDetector` must produce output in this exact shape so it is swap-compatible with
the real detector.

## The model must not

- decide the final count;
- decide user-facing certainty;
- identify people;
- perform face recognition;
- save frames;
- upload frames.

## Class list discipline

- The model's class list and `ToyCategoryRegistry` must stay in sync.
- Changing a label, adding a class, or removing a class requires updating the registry in
  the same change. See [business-logic-principles.md](business-logic-principles.md).
- A label the registry does not know is treated as `unknown` and ignored — never counted.

## Versioning & evaluation

- Every exported model has a version recorded (and, later, a `ModelVersionRepository`).
- Models are evaluated before promotion; accuracy/latency are recorded.
- Model selection and dataset rules are owned by the AI Vision Model Agent.

## TFLite runtime (Phase 2c.0 foundation)

The native inference runtime sits behind the `ToyModelRuntime` seam; only
`tflite_interpreter_factory.dart` imports `tflite_flutter`.

- **Model file:** `assets/models/toy_detector.tflite` (none committed yet).
- **Input:** `[1, inputHeight, inputWidth, 3]` float; normalized
  `(pixel - inputMean) / inputStd` (defaults `0 / 255`).
- **Supported camera formats (Phase 2c.1):** Android **YUV420** (planar or
  semi-planar; honors Y/U/V row & pixel strides; BT.601 full-range → RGB) and
  iOS **BGRA8888** (channel reorder). Conversion is pure and synthetic-plane
  tested in `image_format_converter.dart`. Unsupported formats and short/empty
  planes fail with `TfliteRuntimeException` → frame dropped (non-fatal).
- **Orientation:** the input buffer is in the camera's native (sensor)
  orientation. Rotation to upright is **not** applied yet — it depends on device
  sensor orientation and is a Phase 2c.2 / on-device concern. We do not guess
  transforms without device QA.
- **Geometry foundations (Phase 2c.2):** pure, tested helpers in
  `lib/detection/geometry/` prepare orientation + box mapping but are **not wired
  into production**. `FrameOrientation` (sensor+device° → clockwise quarterTurns,
  default none = no rotation); `RotationTransform.rotateNormalized` (0/90/180/270)
  with `clampNormalized`; `BoundingBoxMapper` (normalized ↔ pixel, non-positive dims
  throw); `PreviewCoordinateMapper` (`BoxFit.cover` scale/offset + normalized →
  preview-pixel). To display correctly the pipeline must eventually (1) rotate by
  `quarterTurns`, then (2) map into the cover-cropped preview. **`BoxFit.cover`
  crops one axis**, so a mapped box can exceed the viewport (overlay clips);
  exact alignment + correct rotation **must be validated on a physical device**.
- **Output (SSD-style, indices configurable in `ToyModelConfig`):** boxes
  `[1, N, 4]` as `[ymin, xmin, ymax, xmax]`, classes `[1, N]`, scores `[1, N]`,
  `N = maxDetections`.
- **Class order** must map to `ToyModelConfig.labels`, all registry-known
  (enforced by `ModelMetadataValidator`).
- **Fallback:** missing/invalid model or mismatched shapes → fall back to
  `MockToyDetector`; per-frame preprocessing/inference errors drop the frame
  rather than crash the loop.
- **Default:** `toyDetectorModeProvider = mock`. TFLite is opt-in via
  `ToyDetectorMode.tfliteWithFallback` and only active once a valid model loads
  and its shapes validate.
- The model still makes **no** business decision (toy-ness, confidence
  acceptability, ignore rules, count) — those remain in the business layer.

Guardrail: [skills/preserve-ai-model-discipline.md](skills/preserve-ai-model-discipline.md).
