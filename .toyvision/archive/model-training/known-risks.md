# Known Risks — ToyVision Detector

Forward-looking risk register for the real TFLite detector. The default
detector remains `MockToyDetector`; `TfliteToyDetector` is gated behind
`FallbackToyDetector` and **Phase 2d physical-device QA is BLOCKED** (no
Android device or usable emulator). Nothing here claims QA has passed.

Each risk lists a short description, the **owner** (which layer or agent
mitigates it), and a **first action** — the smallest concrete next step.

Cross-references:

- [../ai-model-guidelines.md](../ai-model-guidelines.md)
- [../business-logic-principles.md](../business-logic-principles.md)
- [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md)
- [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md)
- [dataset-plan.md](dataset-plan.md)
- [class-taxonomy.md](class-taxonomy.md)
- [labeling-guidelines.md](labeling-guidelines.md)
- [evaluation-plan.md](evaluation-plan.md)

## Dataset and class composition

### Underrepresentation of a toy class

- **Description:** A canonical toy class (`toy_car`, `toy_truck`, `doll`,
  `stuffed_animal`, `building_blocks`, `ball`, `action_figure`, `toy_train`,
  `puzzle`, `board_game`) has too few examples or low variety, producing
  systematically low recall for that class.
- **Owner:** AI Vision Model Agent (dataset).
- **First action:** In [dataset-plan.md](dataset-plan.md), pin a per-class
  minimum sample count and per-class variety budget (color, scale,
  background, lighting); flag any class under floor before training.

### Class imbalance, especially negatives

- **Description:** Negative / ignored classes (`person`, `pet`, `book`,
  `pillow`, `cup`, `remote_control`, etc.) dominate or are absent. Either
  case skews the model: missing negatives cause false positives on people
  and household objects; over-weighted negatives suppress real toys.
- **Owner:** AI Vision Model Agent (dataset + loss weighting); evaluation
  gates in [evaluation-plan.md](evaluation-plan.md).
- **First action:** Define a target positive/negative ratio in
  [dataset-plan.md](dataset-plan.md) and require per-class precision and
  recall slices — including ignored categories — in the evaluation gate.

### Overfitting on a single home / room

- **Description:** Training data captured in one home leads to a model that
  performs well on that floor, lighting, and rug pattern, but degrades in
  any other environment.
- **Owner:** AI Vision Model Agent (dataset diversity) + evaluation
  hold-out policy.
- **First action:** Require at least N distinct rooms / locations in the
  dataset plan and a held-out **unseen-location** slice in
  [evaluation-plan.md](evaluation-plan.md); fail promotion if that slice
  underperforms the seen-location slice beyond a fixed delta.

## Real-world visual conditions

### Small-toy detection

- **Description:** Small objects (single blocks, small action figures,
  marbles, puzzle pieces) sit near or below the model's effective spatial
  resolution at `[1, 320, 320, 3]` and are missed.
- **Owner:** AI Vision Model Agent (architecture/input size) + Business
  Logic Layer (minimum box size policy in `ToyDetectionRules`).
- **First action:** Add a small-object slice (box area below a threshold)
  to [evaluation-plan.md](evaluation-plan.md); document an explicit
  minimum-area policy in `ToyDetectionRules` so undersized boxes are
  rejected predictably rather than silently flickering.

### Partial occlusion

- **Description:** Toys partially behind other toys, hands, or furniture
  produce low-confidence or fragmented boxes; tracking may treat the same
  toy as multiple identities.
- **Owner:** AI Vision Model Agent (training augmentation) +
  `ToyTrackingEngine`.
- **First action:** Require occlusion augmentation in the training
  pipeline; add an occlusion slice to evaluation; keep IOU / hysteresis
  thresholds in `ToyTrackingEngine` tunable rather than hard-coded.

### Motion blur on a moving phone

- **Description:** The user pans the phone over a play area; frames are
  motion-blurred and detections drop or jitter.
- **Owner:** Detection Layer (`RealtimeDetectionConfig`) + AI Vision Model
  Agent (augmentation).
- **First action:** Include motion-blur augmentation in training; expose
  and document `targetInferenceFps` in `RealtimeDetectionConfig` so the
  pipeline can throttle when frames are unusable; the business layer must
  not count from a single blurred frame (use tracking smoothing).

### Orientation / rotation mismatch

- **Description:** Per [../ai-model-guidelines.md](../ai-model-guidelines.md)
  TFLite geometry section, the input buffer is in **sensor orientation** and
  rotation to upright is **not** applied yet. If the model was trained on
  upright images, sensor-oriented inputs will be effectively rotated 90° /
  180° / 270° at inference, collapsing accuracy.
- **Owner:** Detection Layer (`FrameOrientation`, `RotationTransform`,
  `BoundingBoxMapper`, `PreviewCoordinateMapper`) + Phase 2d on-device QA
  ([../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md)).
- **First action:** Do **not** enable TFLite by default until Phase 2d
  validates the rotation path on a real device; keep the geometry helpers
  pure-tested and only wire them into production after on-device QA. Note
  the expected orientation of training images explicitly in
  [dataset-plan.md](dataset-plan.md) and
  [labeling-guidelines.md](labeling-guidelines.md).

### `BoxFit.cover` preview crop affecting visual alignment

- **Description:** The camera preview uses `BoxFit.cover`, which crops one
  axis. Boxes returned by the model are in the **full** camera frame, not
  the cropped preview. Without `PreviewCoordinateMapper`, boxes appear
  shifted or scaled relative to what the user sees, even when the model is
  correct.
- **Owner:** UI Layer + Detection Layer (`PreviewCoordinateMapper`).
- **First action:** Ensure overlay rendering routes all boxes through
  `PreviewCoordinateMapper` (cover scale + offset), and add a manual QA
  check in [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md)
  that a known toy at a frame edge aligns visually.

## Confusable / negative classes

### False positives on similar non-toy objects

- **Description:** Books, pillows, cups, remotes, and other household items
  share silhouette or texture with toys (e.g. board game ↔ book, ball ↔
  cup, action figure ↔ remote) and are detected as toys.
- **Owner:** AI Vision Model Agent (hard negatives) + `ToyCategoryRegistry`
  (ignored categories) + `ToyDetectionRules` (confidence + size gates).
- **First action:** Add hard-negative examples for `book`, `pillow`, `cup`,
  `remote_control`, `phone`, `bottle` in [dataset-plan.md](dataset-plan.md);
  ensure each is present as a label in [class-taxonomy.md](class-taxonomy.md)
  and mapped to the ignored set in `ToyCategoryRegistry`; raise the
  confidence floor for confusable classes in `ToyDetectionRules`.

## Counting / tracking interactions

### Duplicate counting if tracking thresholds are not retuned

- **Description:** `MockToyDetector` produces stable, synthetic detections.
  Real detections jitter in position, class, and confidence. Tracking
  thresholds tuned on the mock can fragment one toy into multiple
  identities, inflating the count — a business-layer correctness failure,
  not a model failure. See
  [../business-logic-principles.md](../business-logic-principles.md).
- **Owner:** `ToyTrackingEngine` + `ToyCountingService`.
- **First action:** When TFLite is first enabled behind the fallback, run a
  manual session on a known scene with a fixed toy count and retune IOU,
  confirmation frames, and disappearance grace in `ToyTrackingEngine`
  before any default switch.

## Runtime / device

### On-device latency on low-end Android phones

- **Description:** Inference at `320x320` plus YUV→RGB conversion can
  exceed the frame budget on entry-level Android hardware, causing dropped
  frames, UI jank, and battery drain.
- **Owner:** Detection Layer (`RealtimeDetectionConfig`) + AI Vision Model
  Agent (model size).
- **First action:** Keep a **smaller** model variant as the shipping
  candidate (nano-class YOLO); expose `targetInferenceFps` in
  `RealtimeDetectionConfig` and document a lower default for low-end
  devices; record p50 / p95 inference latency per device tier in
  [evaluation-plan.md](evaluation-plan.md).

### TFLite runtime / library compatibility across Android API levels

- **Description:** `tflite_flutter` and its native delegates have varying
  behavior across Android API levels and ABIs; an op may be unsupported
  or fall back silently to CPU, producing wrong results or crashes.
- **Owner:** Detection Layer (`tflite_interpreter_factory.dart`,
  `ToyModelRuntime` seam) + Phase 2d QA.
- **First action:** Pin the supported minimum Android API level and ABI
  set in the training pipeline export contract
  ([export-to-tflite.md](export-to-tflite.md)); ensure
  `TfliteRuntimeException` is caught and routed to fallback (already
  wired); add an "API level matrix" row to
  [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md).

### Model unavailability → graceful fallback to mock

- **Description:** The `.tflite` asset is missing, corrupt, or has
  mismatched tensor shapes. Without a fallback, the app would crash or show
  empty detections.
- **Owner:** Detection Layer (`FallbackToyDetector` wrapping
  `TfliteToyDetectorAdapter`).
- **First action:** This is **already wired**: when the model is missing
  or invalid the app falls back to `MockToyDetector` and
  `FallbackToyDetector.usingFallback == true`. Keep this path as the
  default until Phase 2d on-device QA passes; verify it manually per
  [../manual-qa/phase-2c-tflite.md](../manual-qa/phase-2c-tflite.md) rows
  3 and 4.

## Privacy interactions

Every mitigation above must respect
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md): no
faces, no child identification, no person identity labels, no silent
upload, no silent video, no training on user images without consent, no
saving video by default. A risk mitigation that would require violating
these rules is not a valid mitigation — the rule wins, the mitigation is
replaced.
