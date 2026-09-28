# Model contracts

## Bundled detector

- Runtime asset: `assets/models/cleanup_items.tflite` (62,764,989 bytes,
  SHA-256 `E30E3A03995A2F7E2FFB929D8BA26736EBBE2D275049A64FB35DF7A5F4657FEE`).
- Export metadata: Ultralytics 8.4.60, YOLOv8s-world detect, batch 1,
  480×480×3, float32 (`half: false`, `int8: false`), stride 32, NMS not baked
  into the exported model metadata.
- Runtime config: proposal confidence 0.12, IoU 0.5, camera `720p`, optional GPU via
  `TOYVISION_USE_GPU`.
- Source/export model and `ultralytics_yolo` runtime are AGPL-marked;
  closed-commercial distribution remains blocked pending compatible licensing
  or replacement.

The 30 prompt/class names preserve the complete toy vocabulary and add common
loose cleanup items. They are export/training provenance and diagnostic
output, never runtime acceptance rules. A proposal below the conservative
confirmation confidence is not accepted unless the label-independent fused
evidence reaches the global confirmation score.

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
