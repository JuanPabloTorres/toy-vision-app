# Dataset Validation Checklist — ToyVision Prototype (Phase 3.8)

The quality bar a candidate dataset must clear **before** training is
allowed to run. Mechanical checks first; human-judgement checks second;
privacy gate last. Training is blocked until every gate below is satisfied
or has a deliberate, recorded waiver from the project owner.

This checklist is invoked from
[colab-training-plan.md](colab-training-plan.md) Cell 3 (programmatic
checks) and from the project owner's pre-training privacy review
(human-judgement and privacy gates).

Sibling docs:

- [dataset-plan.md](dataset-plan.md) — sources, sizes, splits, balance.
- [labeling-guidelines.md](labeling-guidelines.md) — box rules.
- [privacy-rules.md](privacy-rules.md) — non-negotiable privacy bar.
- [training-pipeline.md](training-pipeline.md) — class label set.
- [custom-detector-strategy.md](custom-detector-strategy.md) — dataset
  minimum (§9) and production target (§10).

## Canonical label set

The dataset must use exactly these 14 labels — no extras, no aliases
(e.g. no `stuffed-animal` with a hyphen, no `legos` for
`building_blocks`):

```text
toy_car
toy_truck
doll
stuffed_animal
building_blocks
ball
action_figure
toy_train
puzzle
board_game
not_toy
person
pet
book
```

`unknown` is **not** a model class. Anything that doesn't fit the 14 set
goes under `not_toy` if it's clearly visible and identifiable, otherwise
is omitted from annotation entirely.

## Gate A — Structural checks (mechanical, scripted)

Run via [colab-training-plan.md](colab-training-plan.md) Cell 3.

- [ ] **Folder layout matches**
      [training-pipeline.md](training-pipeline.md) §1: `train/images/`,
      `train/annotations/`, `val/images/`, `val/annotations/`,
      `test/images/`, `test/annotations/`.
- [ ] **Every image has a matching annotation file** (same stem). No
      orphan images, no orphan XMLs.
- [ ] **Every annotation parses** as PASCAL VOC XML (root `<annotation>`,
      `<size>`, one or more `<object>` blocks each with `<name>` and
      `<bndbox>`).
- [ ] **Every `<name>` is in the canonical 14-label set.** Stray labels
      block training.
- [ ] **Every `<bndbox>`** has `0 ≤ xmin < xmax ≤ width` and
      `0 ≤ ymin < ymax ≤ height`. Degenerate boxes block training.
- [ ] **No empty annotation file** unless the image is a designated
      negative-only (no-toy) frame — those are explicitly allowed for
      false-positive training.

## Gate B — Coverage (mechanical, with human review)

Run via a small notebook cell that counts boxes per class per split.

- [ ] **Prototype size:** total 300–500 images across train/val/test.
      (Reference: [custom-detector-strategy.md](custom-detector-strategy.md) §9.)
- [ ] **Per toy class:** at least **20** boxes in train, at least **5**
      boxes in val. A class below the floor goes back for collection
      before training.
- [ ] **Per ignored class** (`person`, `pet`, `book`, `not_toy`): at
      least **15** boxes in train. The model needs negatives to learn
      what to suppress.
- [ ] **Multi-toy images:** at least 50 across the dataset. Toy-on-toy
      scenes are where the prototype most often fails — they need
      explicit representation.
- [ ] **Negative-only images** (no toy boxes, only background or
      `person` / `book` / `pet` / `not_toy`): at least 30 across the
      dataset. Without these, the model false-positives on plain rooms.

## Gate C — Variation (human-review)

Scan a 10–20 image sample per axis and confirm coverage. Mark each axis
"present" / "thin" / "missing" in the version-record block in
[model-versioning.md](model-versioning.md).

- [ ] **Lighting:** indoor daylight, indoor night with lamp, mixed warm
      light. Each axis should have ≥ 10% of the dataset.
- [ ] **Occlusion:** 0–25% (mostly visible), 25–50% (partially behind
      another object), 50–75% (mostly hidden). The 25–75% buckets are
      what makes the model robust — without them it only works on
      pristine staged shots.
- [ ] **Scale:** small toy (< 5% of frame area), medium toy (5–25%),
      large toy (> 25%). The dataset must include all three; small toys
      are the failure mode the COCO baseline missed entirely.
- [ ] **Background variety:** floor (hard + soft), shelf, table, inside
      a box/container, on top of furniture. Avoid shooting every image
      against the same surface.
- [ ] **Toy-on-toy proximity:** at least 50 images with two or more
      toys within 0.5× their own width of each other (forces the model
      to localize, not just classify the room).
- [ ] **Confusable non-toys:** the `not_toy` and `book` classes include
      real-world objects that LOOK similar to the toy classes — a real
      car for `toy_car`, a real plush blanket for `stuffed_animal`, a
      real building (architectural toy?) for `building_blocks`. The
      hard negatives are how the model learns the difference.

## Gate D — Splits

- [ ] **Train / val / test = 70 / 15 / 15** (rough; ±2% is acceptable).
- [ ] **No image leaks across splits.** Each image stem appears in
      exactly one split.
- [ ] **Held-out unseen-toy subset in `test`.** At least one toy instance
      per class that is **physically a different specimen** than the
      training instances of that class — e.g. if the train set is mostly
      a specific red toy car, the test set includes a different toy car
      (different colour or model). This is the cheapest defence against
      memorization.

## Gate E — Privacy review (human, project-owner sign-off)

Per [privacy-rules.md](privacy-rules.md). Every image in the dataset
must clear all of these.

- [ ] **No identifiable faces.** A child's face, anywhere in the frame,
      blocks the entire image. Adults' faces blocked unless deliberately
      blurred/cropped AND the adult is the project owner who explicitly
      consented to this dataset.
- [ ] **No children in the frame at all** — not just their faces. Even
      torso/hand-only shots of a child are blocked. The toy is the
      subject; the child is not.
- [ ] **No private home details.** Mail with names/addresses, computer
      screens displaying personal information, framed family photos,
      anything that identifies the home or its inhabitants.
- [ ] **No third-party intellectual property in a way that misrepresents
      the project.** Brand-name toys captured incidentally are fine for
      on-device training; this is not commercial republishing.
- [ ] **EXIF stripped or never written.** Camera defaults that record
      GPS / device serial are disabled or stripped at capture.
- [ ] **No upload of the raw dataset to any third-party service** beyond
      the project owner's private Google Drive. No Hugging Face, no
      Roboflow, no public Drive link.
- [ ] **No image of the dataset is committed to this repository.**
      `.gitignore` blocks `datasets/`. A future check should also block
      `*.jpg`/`*.png` outside `assets/` to prevent accidental commits.

## Gate F — Repeatability

- [ ] **Dataset snapshot ID assigned.** A short identifier
      (`toyvision-2026-MM-DD`) recorded in
      [model-versioning.md](model-versioning.md). Future re-trainings
      reference this snapshot rather than "the dataset on Drive at the
      time".
- [ ] **Capture log exists.** A short text file in the dataset folder
      that lists: who captured, what date range, what devices, what
      lighting conditions, what toys (by inventory tag if any). One line
      per capture session.
- [ ] **Annotation tool version recorded.** Which tool was used to
      produce the XMLs (e.g. CVAT, LabelImg, Label Studio) and its
      version, so re-labeling produces consistent geometry.

## Waiver policy

If a gate cannot be satisfied for a known reason (e.g. a class has only
15 boxes in train because that toy is rare in the home), the project
owner may **explicitly waive** the gate by:

1. Recording the waived gate, the reason, and the expected impact in
   [model-versioning.md](model-versioning.md) for that dataset
   snapshot.
2. Re-running the training acknowledging the waiver in the version log.

Waiving a privacy gate (E) is **never** acceptable. Waiving a structural
gate (A) is **never** acceptable — those checks exist to prevent silent
data corruption.

Coverage gates (B, C) may be waived for the prototype; production
default-promotion may not.

## Output of this checklist

A single artifact attached to the model version record:

```text
dataset_snapshot: toyvision-2026-MM-DD
gates:
  A_structural:  pass | fail (details)
  B_coverage:    pass | fail (per-class shortfalls)
  C_variation:   pass | thin (which axes)
  D_splits:      pass | fail
  E_privacy:     pass | fail
  F_repeatability: pass | fail
waivers:
  - gate: ...
    reason: ...
    expected_impact: ...
overall: trainable | blocked
```

If `overall: trainable`, the Colab notebook may proceed past Cell 3. If
`blocked`, training does not run.
