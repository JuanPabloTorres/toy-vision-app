---
name: toyvision-yolo-tflite-debugging
description: Diagnose YOLO/TFLite over-detection, under-detection, box, orientation, or decoding faults from pixels through accepted native proposals.
---

# PURPOSE

Determine whether the first error is acquisition, preprocessing, tensor input,
inference output, decode/NMS, coordinate conversion, or preview display.

# WHEN TO USE

Use when YOLO detects everything/nothing, boxes are shifted/scaled/rotated,
scores are implausible, or device/plugin output differs from export behavior.

# INPUTS

- `assets/models/toys.tflite` hash and export metadata.
- Plugin/runtime/device versions and `YoloModelConfig`.
- A representative source frame, native decoded payload, and raw tensor trace
  when the plugin exposes one.
- Expected box in source and preview coordinates.

# PROCEDURE

1. Verify model identity, task, input shape/dtype/layout, class/output shapes,
   quantization, and preprocessing contract.
2. Record source pixels, resize/letterbox/orientation, tensor min/max/sample.
3. Inspect raw output distribution and axis interpretation when available.
4. Decode one proposal manually: objectness/class semantics, coordinates, and
   score composition; then inspect NMS.
5. Trace that proposal through `YoloStreamingFrameAdapter` normalization and
   the preview cover transform.
6. Identify the first divergent value. Only then test a focused correction.
7. Re-run hard negatives and representative positives; preserve raw evidence.

# TOOLS

`tools/toy_model_export/**`, model metadata/logs, SHA-256, Android logs, plugin
stream payload, developer overlay, adapter tests, and physical-device capture.

# EXPECTED OUTPUT

Model/runtime contract table, one numerical end-to-end example, first incorrect
state, correction owner, and positive/hard-negative results.

# FAILURE CONDITIONS

Do not claim raw decoding proof from boxes alone. `BLOCKED` is correct when the
plugin hides the required tensor/preprocessing data. Raising confidence alone
is not a diagnosis.

# QUALITY GATES

Adapter pixel/label tests, coordinate overlay evidence, representative
positive/negative corpus metrics, no new false collection, and target-device
TFLite validation.
