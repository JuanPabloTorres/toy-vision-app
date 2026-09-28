# Model contracts

## Bundled detector

- Runtime asset: `assets/models/toys.tflite` (62,664,952 bytes at audit).
- Export metadata: Ultralytics 8.4.60, YOLOv8s-world detect, batch 1,
  480×480×3, float32 (`half: false`, `int8: false`), stride 32, NMS not baked
  into the exported model metadata.
- Runtime config: confidence 0.25, IoU 0.5, camera `720p`, optional GPU via
  `TOYVISION_USE_GPU`.
- Source/export model and `ultralytics_yolo` runtime are AGPL-marked;
  closed-commercial distribution remains blocked pending compatible licensing
  or replacement.

The 20 prompt/class names are export/training provenance and diagnostic output.
They must not be runtime toy acceptance rules.

## Camera adapter

The plugin payload must provide `originalImage`; missing pixels throw
`CameraFrameAdapterException`. Each valid native normalized box/confidence is
preserved. The adapter assumes plugin `normalizedBox` left/top/right/bottom are
already normalized and clamps the resulting rectangle.

## Embeddings

`PerceptualEmbeddingExtractor` is an engineered local visual descriptor. It is
not a trained semantic toy embedding. Use it for similarity/identity/scene
evidence only until corpus calibration demonstrates another capability.

Any model/runtime replacement must record source, license, versions, hash,
input/output shapes, dtype, normalization, resize/letterbox, score semantics,
NMS, coordinate/orientation mapping, delegate, and a fresh corpus/device result.
