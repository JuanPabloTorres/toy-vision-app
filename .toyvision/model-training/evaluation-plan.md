# Evaluation Plan — ToyVision Detector

How a candidate `toy_detector.tflite` earns the right to replace `MockToyDetector`
behind `TfliteToyDetectorAdapter`. The model only **detects**; final count, toy
validity, duplicate identity, and ignored behavior are decided by the business
layer (`ToyCategoryRegistry`, `ToyDetectionRules`, `ToyTrackingEngine`,
`ToyCountingService`). This plan grades the detector against that contract.

See also: [training-pipeline.md](training-pipeline.md),
[known-risks.md](known-risks.md), and the broader
[../testing-strategy.md](../testing-strategy.md).

## Status

- **Default detector:** `MockToyDetector` (TFLite is a fallback path).
- **Phase 2d physical-device QA:** **BLOCKED** — no Android device or emulator
  available. No QA pass has been performed. This plan describes the bar; it does
  **not** assert that the bar has been cleared.

## Class taxonomy under test

Canonical model index `0..n` must match `ToyModelConfig.labels` and
`ToyCategoryRegistry`:

```
toy_car, toy_truck, doll, stuffed_animal, building_blocks, ball,
action_figure, toy_train, puzzle, board_game, not_toy,
person, pet, book, unknown
```

Ignored / negative categories (never counted, regardless of score):
`person, pet, shoe, clothes, bottle, cup, furniture, bed, pillow, phone,
remote_control, book, unknown`.

## Held-out test set

The test set lives outside training/validation and is frozen per model version.
It must contain, at minimum, the scenarios in the table below. Each scenario
needs ≥ 30 labeled frames covering varied lighting, angles, and household
backgrounds, captured under the privacy rules in
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md) (consented,
no child identification, no faces stored for training).

Frames are annotated with: ground-truth boxes, ground-truth class (from the
canonical list), and scenario tags. Negative scenarios are annotated with
**zero** toy boxes — distractor objects are labeled as their ignored class.

## Metrics

Detector-level (model only):

- **mAP@0.5** over toy classes (excluding ignored classes).
- **Per-class AP@0.5** for each toy class.
- **False-positive rate on negatives (FPRN):** fraction of negative frames in
  which the detector emits ≥ 1 box of a toy class above
  `ToyDetectionRules.minModelConfidence`.
- **Per-frame inference latency** on a mid-range Android phone (target class:
  Snapdragon 6-series / Tensor G-series, 6 GB RAM), measured end-to-end from
  preprocessed input tensor to raw outputs. Reported as p50 and p95 over
  ≥ 500 frames.
- **Model load time** (cold start) and **peak runtime memory**.

System-level (model + business layer, run via `scenario_builders.dart`-style
fixtures wrapping the candidate detector):

- **Count accuracy** per scenario: `|predicted_count - true_count|`.
- **Duplicate rate:** counts emitted for the same tracked identity beyond 1.
- **Ignored-category leakage:** counts attributed to any ignored class.

## Scenarios and acceptance thresholds

Thresholds are **ranges**, intentionally — exact targets are set per model
version in `training-pipeline.md` and recorded with the model version. A model
that meets *every* row's range, on the held-out set, is eligible for Phase 2d
device QA.

| # | Scenario | Expected behavior | Detector threshold | System threshold |
|---|----------|-------------------|--------------------|------------------|
| 1 | Single toy, centered | 1 box, correct toy class | per-class AP@0.5 ≥ **0.70–0.85** | counted exactly 1 |
| 2 | Multiple toys (2–5) | One box per toy, correct classes | mAP@0.5 ≥ **0.65–0.80** | count error 0 on ≥ 90% of clips |
| 3 | Cluttered room | Boxes only on toys; clutter ignored | FPRN ≤ **0.05–0.10** | ignored leakage = 0 |
| 4 | Toy pile (6–15 toys, overlapping) | At least the visible toys boxed | recall@0.5 ≥ **0.55–0.70** | count within **±20%** of true |
| 5 | Small toy (≤ 5% frame area) | Detected with confidence above min | recall@0.5 ≥ **0.40–0.60** | counted at least once across clip |
| 6 | Partial occlusion (≥ 30% hidden) | Detected when ≥ 50% visible | recall@0.5 ≥ **0.45–0.65** | identity preserved by tracker |
| 7 | Low light (≤ 50 lux equivalent) | Degrades gracefully, no garbage boxes | FPRN ≤ **0.10–0.15**, recall ≥ **0.40** | no spurious counts |
| 8 | Motion blur (hand-held pan) | Drops frames rather than hallucinates | FPRN ≤ **0.10–0.15** | count stable, no explosion |
| 9 | Similar non-toy (pillow vs. stuffed_animal, cushion vs. ball) | Classified as `pillow` / `not_toy` / `unknown` | FPRN ≤ **0.05–0.10** | never counted |
| 10 | Person visible (no toys) | Person boxed as `person` or no box | toy-class FPRN ≤ **0.02–0.05** | count = 0; person never counted |
| 11 | Pet visible (no toys) | Pet boxed as `pet` or no box | toy-class FPRN ≤ **0.02–0.05** | count = 0; pet never counted |
| 12 | Camera rotation (portrait & landscape) | Detections in both; sensor-orientation input only | per-class AP@0.5 within **±10%** of portrait baseline | count parity ±1 |
| 13 | Pure negatives (empty room, books on shelf) | Zero toy boxes | FPRN ≤ **0.02–0.05** | count = 0 |
| 14 | Duplicate-prone (same toy across many frames) | Many frames, one identity | tracker-handled; model emits stable boxes (IoU drift ≤ **0.2** frame-to-frame) | counted exactly 1 — **duplicate prevention is the business layer's job, not the model's** |

Latency budget (applies to all scenarios):

- **p50 ≤ 80–120 ms/frame** on the target Android class.
- **p95 ≤ 150–200 ms/frame**.
- Cold model load ≤ **1.5–2.5 s**.
- Peak runtime memory ≤ **200–300 MB** above baseline.

Frames that exceed the latency budget are dropped at the runtime seam
(non-fatal); a model whose **p50** exceeds budget fails this plan regardless of
accuracy.

## Reporting

Each evaluation run produces:

1. A metrics table (the rows above) with measured values and the range used.
2. Per-class confusion matrix over toy + ignored classes.
3. Latency histogram (device, OS version, model version recorded).
4. Failure gallery: up to 20 representative misses and 20 false positives.
5. The model version, dataset version, and training config hash.

Results are attached to the model version record (future
`ModelVersionRepository`). A model is **not** promoted on numbers alone — the
gallery must be reviewed for privacy and safety regressions
([../privacy-safety-guidelines.md](../privacy-safety-guidelines.md)).

## End-to-end acceptance

A candidate model is acceptable to ship behind `TfliteToyDetectorAdapter` only
when **all** of the following hold:

1. Every scenario row meets its detector-level threshold on the held-out set.
2. Every scenario row meets its system-level threshold when wrapped by the real
   business layer (`ToyDetectionRules` + `ToyTrackingEngine` +
   `ToyCountingService`), using the scenario fixtures described in
   [../testing-strategy.md](../testing-strategy.md).
3. Latency p50 / p95 and memory budgets are met on the target Android class.
4. Class taxonomy and label order exactly match `ToyModelConfig.labels` and
   `ToyCategoryRegistry`; ignored categories never produce counts in system
   tests.
5. Privacy review of the failure gallery passes — no faces, no child
   identification, no person-identity labels, no frames retained beyond the
   evaluation run.
6. **Phase 2d physical-device QA passes** on a real mid-range Android device:
   preview alignment, sensor-orientation → upright mapping, portrait/landscape
   parity, and pause / resume / reset all behave per
   [../realtime-detection-flow.md](../realtime-detection-flow.md).

Until step 6 is performed on hardware, the model **stays behind the fallback
flag** and `MockToyDetector` remains the default. This plan never authorizes
shipping a model on metrics alone.

## Risks that can invalidate a passing run

See [known-risks.md](known-risks.md) for the full list. Highlights that
specifically threaten this evaluation:

- Test-set leakage from the training set inflates mAP.
- Synthetic / web-scraped toy images failing to generalize to real home scenes.
- Sensor-orientation mismatch between training data and device input (Phase
  2c.2 geometry is not yet wired into production).
- Distribution drift across device cameras (FOV, white balance, noise) not
  represented in the held-out set.
