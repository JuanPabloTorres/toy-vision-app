# Toy detection models

Place the TFLite model here as **`toy_detector.tflite`** (the path in
`ToyModelConfig.defaults`). No model file is committed; until one exists the app
runs on the mock detector.

## Expected model contract

| Property | Expectation |
|----------|-------------|
| File name | `toy_detector.tflite` |
| Input | `[1, 320, 320, 3]` float (configurable via `ToyModelConfig.inputWidth/Height`) |
| Input normalization | `(pixel - inputMean) / inputStd` → defaults `0 / 255` (0..1) |
| Output: boxes | tensor index `0`, shape `[1, N, 4]`, `[ymin, xmin, ymax, xmax]` normalized |
| Output: classes | tensor index `1`, shape `[1, N]` (float indices) |
| Output: scores | tensor index `2`, shape `[1, N]` |
| `N` | `ToyModelConfig.maxDetections` (default 25) |

If a chosen model differs (different indices, box format, or output count),
change only `ToyModelConfig` and `TfliteTensorOutputParser` /
`TfliteToyDetectorAdapter` — never the business layer.

## Camera image preprocessing (Phase 2c.1)

Frames are converted to the model input by `CameraImagePreprocessor` via the pure
`ImageFormatConverter`:

- **YUV420 (Android):** BT.601 full-range → RGB, honoring Y/U/V row and pixel
  strides (planar or semi-planar).
- **BGRA8888 (iOS):** channel reorder → RGB.
- Then nearest-neighbor resize to `inputWidth × inputHeight` and normalize.
- Unsupported formats / short planes throw `TfliteRuntimeException` and the frame
  is dropped (no crash).

**Orientation limitation:** the buffer is in the camera's native sensor
orientation; rotation to upright is deferred to on-device validation (2c.2). A
model trained on upright images may need that rotation before it performs well.

## Box coordinate mapping (Phase 2c.2)

Model output boxes are normalized `[ymin, xmin, ymax, xmax]`; the adapter yields
top-left `x,y,w,h` (`BoundingBox`). Pure, tested helpers in
`lib/detection/geometry/` prepare display mapping (**not yet wired**):

1. `FrameOrientation.quarterTurns` + `RotationTransform.rotateNormalized` — rotate
   boxes to upright (default: no rotation until device QA).
2. `PreviewCoordinateMapper.mapNormalizedBoxToPreview` — map into the
   `BoxFit.cover` preview, accounting for scale and the cropped (overflowing) axis.

Because the preview uses `BoxFit.cover`, a mapped box may extend past the viewport
(the overlay clips). Correct rotation and alignment must be verified on a physical
device before the overlay is trusted.

## Class order

The model's class indices must map to `ToyModelConfig.labels`, in order. Every
label must exist in `ToyCategoryRegistry`; `ModelMetadataValidator` rejects the
config otherwise. Keep the class list and the registry in sync in the same change.

## Privacy

The model is a detector only. It must not identify people or perform face
recognition. Frames are read transiently to build the input tensor and are never
saved or uploaded.

## How fallback behaves

`TfliteToyDetector` validates the config, loads the asset, then hands bytes to
`TfliteToyModelRuntime`. If the model asset is missing, the interpreter fails, or
the tensor shapes don't match, it throws `ModelUnavailableException` /
`TfliteRuntimeException` and `FallbackToyDetector` switches to `MockToyDetector`.
At inference time, preprocessing/runtime errors drop the single frame (empty
output) rather than crashing the live loop.

## Why the mock is still the default

`toyDetectorModeProvider` defaults to `ToyDetectorMode.mock`. TFLite is opt-in via
`ToyDetectorMode.tfliteWithFallback` and only becomes the active detector once a
valid model is present and its shapes validate. See
`.toyvision/manual-qa/phase-2c-tflite.md` for how to enable it.
