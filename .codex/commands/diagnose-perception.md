# `diagnose-perception` recipe

Native invocation: `$toyvision-perception-debugging`.

Trace camera pixels → preprocessing/analysis → YOLO/open-set proposals →
embeddings → fusion → tracking → scene/disappearance → `RoomWorldModel`.
Capture a replay, identify the first incorrect state, test one hypothesis, and
report causal evidence. Route raw detector/decode faults to
`$toyvision-yolo-tflite-debugging`.
