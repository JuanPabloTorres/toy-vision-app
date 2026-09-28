# AI Model Guidelines

The detector emits observations only. `YoloDetectionMapper`,
`ToyDetectionRules`, tracking, temporal snapshot quality, progress, and human
confirmation decide product behavior.

- Current inference is on-device through `ultralytics_yolo`.
- Prefer the bundled `assets/models/toys.tflite`; use the configured fallback
  only when the asset is absent.
- Keep packaged model labels synchronized with `YoloModelConfig` and the mapper.
- Never treat an unknown label as a supported toy.
- Never infer completion directly from raw model output or one frame.
- Model replacement, prompt changes, or training require explicit approval,
  versioning, evaluation evidence, and physical-device verification.
- No face recognition, person identification, or silent media upload/storage.
