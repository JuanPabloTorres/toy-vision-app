# Dataset Plan — ToyVision Detector

Forward-looking specification. **No dataset has been collected, no model has been
trained, no `.tflite` is committed.** The default detector is `MockToyDetector`;
real inference is gated and Phase 2d physical-device QA is **BLOCKED**. Nothing
in this plan changes app runtime behavior.

The detector only proposes boxes, class indices, and scores. Counting, validity,
acceptable confidence, duplicate identity, and ignored behavior are owned by the
business layer — see [class-taxonomy.md](class-taxonomy.md) and
[../business-logic-principles.md](../business-logic-principles.md).

## Scope

This document fixes the **shape and size** of the dataset, not how images are
labeled. Box conventions, edge cases, and QA live in
[labeling-guidelines.md](labeling-guidelines.md). Consent, faces, and child
imagery rules live in [privacy-rules.md](privacy-rules.md). Training repro,
hyperparameters, and seeds live in [training-pipeline.md](training-pipeline.md).

## Dataset size targets

Sizes count **labeled images** (each with zero or more boxes). Synthetic
augmentation does **not** count toward these totals — it is applied by the
pipeline, not stored.

| Tier | Total images | Purpose | Expected outcome |
| --- | --- | --- | --- |
| Minimum prototype | **1,500** | First end-to-end TFLite smoke run, sanity check on a few classes. | Detector loads, runs at 320×320, returns plausible boxes on familiar scenes. Not shippable. |
| Working baseline | **5,000–8,000** | First model promoted past mock for internal use. | Usable mAP on the top 4–5 toy classes in well-lit scenes. Still gated by Phase 2d. |
| Recommended production | **15,000–25,000** | First model considered for non-internal use. | Robust on all 10 toy classes across lighting, angle, and clutter slices. |

The prototype tier exists so the pipeline (label format, augmentation, export,
TFLite shape validation) can be exercised before serious data collection. It is
**not** a release candidate under any circumstance.

## Per-class targets

Class list and ignored categories are canonical in
[class-taxonomy.md](class-taxonomy.md). Numbers below count **labeled instances
(boxes)**, not images — a single image can contribute to several classes.

### Toy classes (counted)

Model indices 0..9: `toy_car`, `toy_truck`, `doll`, `stuffed_animal`,
`building_blocks`, `ball`, `action_figure`, `toy_train`, `puzzle`, `board_game`.

| Tier | Instances per toy class | Floor (any class) |
| --- | --- | --- |
| Minimum prototype | **~100** | no class below 60 |
| Working baseline | **400–600** | no class below 250 |
| Recommended production | **1,000–1,500** | no class below 700 |

Balance rule: the largest toy class may not exceed **~2.5×** the smallest toy
class at the recommended tier. If it does, downsample (do not duplicate) before
training.

### Negative / ignored classes (never counted)

Model indices 10..14: `not_toy`, `person`, `pet`, `book`, `unknown`. Additional
ignored objects (`shoe`, `clothes`, `bottle`, `cup`, `furniture`, `bed`,
`pillow`, `phone`, `remote_control`) are labeled under `not_toy` unless a
separate index is added in [class-taxonomy.md](class-taxonomy.md).

| Class | Instances (recommended production) | Notes |
| --- | --- | --- |
| `not_toy` | **1,500–2,500** | Spread across the confusable objects listed above. |
| `person` | **600–1,000** | See privacy rules below; **no faces, no children**. |
| `pet` | **400–700** | Dogs and cats indoors. |
| `book` | **400–700** | Includes children's picture books (frequent false positives for `puzzle` / `board_game`). |
| `unknown` | **as needed** | Reserved sink for label-disagreement cases; do not farm. |

Negative-class instances should reach **~30–40%** of total instances at the
recommended tier. Below that, false-positive rate on empty rooms and clutter
tends to dominate.

## Splits

Splits are by **scene / session**, never by individual image, to prevent
near-duplicate leakage between train and eval.

| Split | Share | Purpose |
| --- | --- | --- |
| Train | **75%** | Gradient updates. |
| Validation | **15%** | Hyperparameter choices, early stopping. |
| Test | **10%** | Frozen. Used only at promotion gates defined in [evaluation-plan.md](evaluation-plan.md). |

Constraints:

- The test split must contain **all** toy classes and **all** ignored classes.
- The test split must contain at least one full session from each environment
  slice (toy box, floor / play-mat, shelf — see below).
- A session contributes to **exactly one** split.

## Image resolution

The runtime input is `[1, 320, 320, 3]` float (see
[../ai-model-guidelines.md](../ai-model-guidelines.md)). Dataset images are kept
at higher resolution and resized by the training pipeline — never pre-resized
to 320×320 on disk.

| Property | Target |
| --- | --- |
| Native capture | **≥ 1280×720**, ideally 1920×1080. |
| Stored long edge | **1280–1920 px**, JPEG quality ≥ 90 or PNG. |
| Aspect ratios | Mix of 4:3 and 16:9; allow portrait sessions for shelves and toy boxes. |
| Smallest labeled box | **≥ 16 px on the long edge after resize to 320**, i.e. ≥ ~64 px on a 1280-px source. |

Anything smaller than the 16-px-at-320 floor is labeled but flagged
`too_small`; see [labeling-guidelines.md](labeling-guidelines.md). The training
pipeline may drop those instances per [training-pipeline.md](training-pipeline.md).

## Variation requirements

Each axis below applies at the **recommended production** tier. Working
baseline must hit at least the lower bound of each range; prototype is exempt
but should still touch every axis at least once.

### Lighting

| Condition | Share of dataset |
| --- | --- |
| Bright daylight (window-lit) | 25–35% |
| Mixed daylight + warm indoor | 20–30% |
| Warm indoor only (evening) | 20–30% |
| Dim / low-light (lamp only) | 10–15% |
| Backlit / strong window glare | 5–10% |

No single lighting condition may exceed **40%** of the dataset.

### Angle

| Camera pose | Share |
| --- | --- |
| Top-down (phone over toy box / floor) | 25–35% |
| ~45° oblique (typical handheld) | 35–45% |
| Eye-level / low angle (shelf, couch) | 20–30% |
| Tilted / rolled handheld | 5–10% |

### Room clutter

| Scene density | Share |
| --- | --- |
| Sparse (1–3 objects in frame) | 20–25% |
| Medium (4–10 objects) | 45–55% |
| Heavy (10+ objects, overlap, partial occlusion) | 25–30% |

Heavy-clutter scenes are the primary source of small-toy and occlusion
instances below.

### Toy box examples

Closed and open toy boxes, bins, baskets, and storage cubes.

- **At least 15% of total images.**
- Must include top-down and oblique shots.
- Must include both "lid open / toys visible" and "lid open / toys overflowing".
- Must include at least one session per common storage material (fabric bin,
  plastic bin, wood crate).

### Floor / play-mat examples

Toys on hardwood, carpet, rug, foam play-mat, tile.

- **At least 25% of total images.**
- Must span at least 4 distinct floor surfaces.
- Must include scenes where the floor pattern itself is busy (e.g., patterned
  rug) — these are a known false-positive source.

### Shelf examples

Toys on shelves, side tables, dressers, IKEA cube units.

- **At least 10% of total images.**
- Must include eye-level and low-angle poses.
- Must include shelves shared with books (overlap with the `book` ignored
  class is intentional and useful here).

### Partial occlusion

Boxes where the toy is partly hidden by another toy, a hand, a piece of
furniture, a blanket, or the edge of the frame.

- **At least 20% of labeled toy instances.**
- The visible fraction must be **≥ ~30%** for the instance to be labeled with
  its real class; below that, see [labeling-guidelines.md](labeling-guidelines.md).
- Frame-edge clipping counts as occlusion and must be represented.

### Small toy examples

Instances whose long edge, after resize to 320, is between **16 px and 32 px**.

- **At least 15% of labeled toy instances.**
- Concentrated in heavy-clutter and shelf slices.
- Required because handheld captures often frame the whole room, not the toy.

### Similar non-toy examples (false-positive suppression)

Objects that look like toys to a 320×320 detector but are not toys. Labeled as
`not_toy` (or the matching ignored class if one exists).

- **At least 10% of total images** must contain at least one such object.
- Required confusables: shoes, slippers, water bottles, sippy cups, TV remotes,
  phones, decorative figurines, plush cushions, throw pillows shaped like
  animals, fruit (real and plastic), pet toys (rope, kong), small appliances.
- Children's picture books deserve their own slice — they are the single
  largest false-positive source for `puzzle` and `board_game`.

### Negative examples (no toys at all)

Images that contain **zero** labeled toy instances.

- **10–15% of total images.**
- Must include: empty rooms, rooms with only adults, rooms with only pets,
  kitchen and bathroom shots, made beds, dining tables, hallways.
- Purpose: the detector must learn that "indoor scene" alone is not evidence
  of a toy. Without this slice, the false-positive rate on tidy rooms is
  unacceptable.

## Privacy

Full rules live in [privacy-rules.md](privacy-rules.md). The non-negotiable
gate, repeated here so dataset work cannot drift:

- **No faces.** Any human face visible in a candidate image must be blurred,
  cropped out, or the image discarded — before the image enters the dataset.
- **No children.** No image identifying, framing, or centered on a child may
  enter the dataset, regardless of consent. Adult `person` instances are
  acceptable under consent; children are not.
- **Consent required.** Every image sourced from a family / contributor
  requires written, revocable consent tied to the session. No consent → no
  image. Consent withdrawal → image and its labels are removed from all
  splits and the dataset version is re-cut.
- **No silent capture.** Images are never collected from the app's live
  pipeline. The app does not save frames and does not upload frames; see
  [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md).
- **No identity labels.** `person` is a single ignored class. There is no
  per-person identity, no name, no demographic tag.

Any conflict between this section and [privacy-rules.md](privacy-rules.md) is
resolved in favor of [privacy-rules.md](privacy-rules.md).

## Folder layout (YOLO-compatible)

Dataset is stored outside the app repo. The on-disk layout maps directly to
what YOLO expects (`images/` + `labels/` parallel trees, one `.txt` per image,
class indices matching [class-taxonomy.md](class-taxonomy.md)).

```
toyvision-dataset/
  dataset.yaml                  # YOLO config: paths, nc, names (canonical order)
  README.md                     # version, source, consent log pointer
  CHANGELOG.md                  # per-version diff (added/removed sessions)
  consent/                      # signed consent records, never shipped with model
    <session-id>.json
  raw/                          # original captures, pre-redaction (restricted)
    <session-id>/
      <image>.jpg
  images/
    train/
      <session-id>__<frame>.jpg
    val/
      <session-id>__<frame>.jpg
    test/
      <session-id>__<frame>.jpg
  labels/
    train/
      <session-id>__<frame>.txt    # one box per line: <class> <xc> <yc> <w> <h>
    val/
      <session-id>__<frame>.txt
    test/
      <session-id>__<frame>.txt
  slices/                       # optional per-axis manifests for eval
    lighting-dim.txt
    angle-topdown.txt
    clutter-heavy.txt
    occlusion.txt
    small-toys.txt
    confusables.txt
    negatives.txt
```

`dataset.yaml` skeleton (class order must match
[class-taxonomy.md](class-taxonomy.md) and `ToyModelConfig.labels`):

```yaml
path: ./
train: images/train
val:   images/val
test:  images/test

nc: 15
names:
  0:  toy_car
  1:  toy_truck
  2:  doll
  3:  stuffed_animal
  4:  building_blocks
  5:  ball
  6:  action_figure
  7:  toy_train
  8:  puzzle
  9:  board_game
  10: not_toy
  11: person
  12: pet
  13: book
  14: unknown
```

Rules:

- Filenames are `<session-id>__<frame>.{jpg,txt}` so split-by-session is
  enforceable by a substring check.
- `raw/` and `consent/` are **never** packaged with an exported model or
  shipped to the app.
- A dataset version is a frozen snapshot of `images/`, `labels/`, and
  `dataset.yaml`. Model provenance points at that version — see
  [training-pipeline.md](training-pipeline.md).

## Cross-references

- [class-taxonomy.md](class-taxonomy.md) — canonical class indices and
  ignored categories; this plan must match it exactly.
- [labeling-guidelines.md](labeling-guidelines.md) — how boxes are drawn,
  occlusion thresholds, edge cases, label QA.
- [privacy-rules.md](privacy-rules.md) — consent records, redaction,
  withdrawal, retention.
- [training-pipeline.md](training-pipeline.md) — how this dataset is consumed,
  augmentation, seeds, export to TFLite at `[1, 320, 320, 3]`.
- [../ai-model-guidelines.md](../ai-model-guidelines.md) — detector contract
  and the mock-first phase rule.
- [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md) —
  cross-cutting privacy non-negotiables.
