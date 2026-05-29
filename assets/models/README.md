# Toy detection models

Place the TFLite model here as `toy_detector.tflite` (the path in
`ToyModelConfig.defaults`).

## Requirements before a model is added

- **Class-label order must match `ToyModelConfig.labels`**, which in turn must
  stay in sync with `ToyCategoryRegistry`. `ModelMetadataValidator` enforces that
  every model label is registry-known.
- The model must be a small/nano on-device detector exported to TensorFlow Lite.
- Output is expected in the common SSD layout consumed by
  `TfliteToyDetectorAdapter`: boxes `[ymin, xmin, ymax, xmax]` (normalized),
  per-detection scores, and class indices.

## Privacy

The model is a detector only. It must not identify people or perform face
recognition, and frames are never saved or uploaded.

No model file is committed yet — until one is present (and the inference runtime
is wired), the app runs on the mock detector.
