# Dataset Card Template — ToyVision Prototype v0.1

Copy this file as `dataset-card.md` inside your local
`toyvision-dataset-v0_1/` folder. **Do not commit it to this repo** —
the dataset (and its card) live outside source control per
[privacy-rules.md](privacy-rules.md) and
[collection-guide.md](collection-guide.md).

Replace every `<…>` placeholder. Keep all section headers. Anything you
deliberately leave blank, mark `n/a` so reviewers can see it was
considered.

---

# ToyVision Dataset — v0.1 (Prototype)

## Identification

- **Dataset name:** ToyVision Prototype v0.1
- **Snapshot ID:** toyvision-`<YYYY-MM-DD>`
- **Created by:** `<project owner name>`
- **Created at:** `<YYYY-MM-DD>`
- **Path on disk:** `<absolute local path>`
- **Total images (raw):** `<count>`
- **Total images (selected):** `<count>`
- **Disk size:** `<bytes>`

## Purpose

> Train the first ToyVision custom toy detector (EfficientDet Lite 0
> via MediaPipe Model Maker) to recognize the canonical 14-class
> taxonomy in real rooms. Prototype scale; not a shipping artifact.

Phase reference:
[custom-detector-strategy.md](custom-detector-strategy.md),
[dataset-capture-pass.md](dataset-capture-pass.md),
[colab-training-plan.md](colab-training-plan.md).

## Class composition

Counts measured against `raw/` (before curation).

| Class | Raw count | Notes |
| --- | --- | --- |
| toy_car | `<n>` | `<distinct specimens, colors covered>` |
| toy_truck | `<n>` | |
| doll | `<n>` | |
| stuffed_animal | `<n>` | |
| building_blocks | `<n>` | |
| ball | `<n>` | |
| action_figure | `<n>` | |
| toy_train | `<n>` | |
| puzzle | `<n>` | |
| board_game | `<n>` | |
| not_toy | `<n>` | |
| person_no_face | `<n>` | n/a if 0 |
| pet | `<n>` | n/a if 0 |
| book | `<n>` | |
| negative_only | `<n>` | |
| uncertain_review | `<n>` | excluded from training |

## Variation coverage

Indicate `present` / `thin` / `missing` per axis per class. If `thin`
or `missing`, note the plan (capture more, or accept the limitation).

| Axis | Coverage | Notes |
| --- | --- | --- |
| Lighting — daylight | `<present/thin/missing>` | |
| Lighting — lowlight | `<present/thin/missing>` | |
| Background — floor | `<present/thin/missing>` | |
| Background — bin | `<present/thin/missing>` | |
| Background — shelf | `<present/thin/missing>` | |
| Composition — closeup | `<present/thin/missing>` | |
| Composition — farshot | `<present/thin/missing>` | |
| Composition — mixed | `<present/thin/missing>` | |
| Occlusion — 25–75% hidden | `<present/thin/missing>` | |
| Confusables — lookalike negatives | `<present/thin/missing>` | |
| Multi-toy frames | `<count>` | target ≥ 50 |
| Negative-only frames | `<count>` | target ≥ 30 |

## Capture environment

- **Devices used:** `<phone model(s), e.g. Galaxy S25>`
- **Date range:** `<YYYY-MM-DD to YYYY-MM-DD>`
- **Locations:** `<rooms / surfaces — no addresses>`
- **Lighting sources observed:** `<natural daylight, warm lamp, etc.>`
- **Approximate session count:** `<3 sessions per the Day 1/2/3 plan>`

## Splits

To be filled after Phase 3.9.1 curation.

| Split | Image count | Toy classes covered | Held-out toys |
| --- | --- | --- | --- |
| train | `<n>` | `<list>` | n/a |
| val | `<n>` | `<list>` | n/a |
| test | `<n>` | `<list>` | `<list of held-out specimens>` |

## Annotation

To be filled after Phase 3.9.2 annotation.

- **Tool:** `<CVAT / LabelImg / Label Studio>`
- **Tool version:** `<vX.Y.Z>`
- **Annotation format:** PASCAL VOC XML
- **Annotator(s):** `<name(s)>`
- **Review pass count:** `<n>` (a second human review of N% of annotations)
- **Reviewed sample size:** `<n>` (`<%>` of total)

## Privacy review

Per [privacy-rules.md](privacy-rules.md) and Gate E in
[dataset-validation-checklist.md](dataset-validation-checklist.md).

- [ ] No identifiable faces in any image.
- [ ] No children in any image (not just no faces — no children, period).
- [ ] No private home details (mail, screens, IDs, addresses).
- [ ] EXIF metadata stripped or never written (GPS disabled at capture).
- [ ] No image uploaded to a third-party service.
- [ ] No image committed to the source repository.
- [ ] No third-party-owned images in the set.

Sign-off:

- **Reviewed by:** `<project owner name>`
- **Reviewed at:** `<YYYY-MM-DD>`
- **Result:** `<pass / blocked + reason>`

## Validation gates

Run [dataset-validation-checklist.md](dataset-validation-checklist.md)
against the dataset and record the result of each gate.

| Gate | Result | Notes |
| --- | --- | --- |
| A — Structural | `<pass / fail>` | |
| B — Coverage | `<pass / fail>` | per-class shortfalls if any |
| C — Variation | `<pass / thin>` | which axes |
| D — Splits | `<pass / fail>` | |
| E — Privacy | `<pass / blocked>` | |
| F — Repeatability | `<pass / fail>` | |

**Overall:** `<trainable / blocked>`

## Waivers

Use only for Gate B / C. Never for A, D, E.

| Gate waived | Reason | Expected impact | Mitigation |
| --- | --- | --- | --- |
| `<e.g. B - puzzle <20 boxes>` | `<rare in home>` | `<weak puzzle recall>` | `<collect more before promoting to default>` |

## Capture log

One line per session. Pasted from `capture-log.md`.

```text
<YYYY-MM-DD> session 1  duration=<HH:MM>  device=<model>  lighting=<daylight/lamp/mixed>  classes={toy_car: <n>, stuffed_animal: <n>, ...}  notes=<…>
<YYYY-MM-DD> session 2  ...
<YYYY-MM-DD> session 3  ...
```

## Storage and lifecycle

- **Primary storage:** `<local path>`
- **Backup:** `<encrypted external drive / private cloud — not third-party
  labeling services>`
- **Retention:** `<until next dataset snapshot supersedes it>`
- **Deletion plan:** `<who deletes when, e.g. on full retraining with
  larger dataset, prototype set may be archived offline>`

## Known limitations

Document anything reviewers should know before treating this dataset
as ground truth.

- `<e.g. all images captured indoors; outdoor performance untested>`
- `<e.g. one specific stuffed bear over-represented relative to other
  plushes — generalization to other plushes is unverified>`
- `<e.g. only one pet specimen photographed; per-breed generalization
  unverified>`

## Pointers (do not change)

The following links point into the repo and stay stable across dataset
versions:

- [class-taxonomy.md](class-taxonomy.md)
- [dataset-plan.md](dataset-plan.md)
- [dataset-capture-pass.md](dataset-capture-pass.md)
- [dataset-validation-checklist.md](dataset-validation-checklist.md)
- [labeling-guidelines.md](labeling-guidelines.md)
- [privacy-rules.md](privacy-rules.md)
- [model-versioning.md](model-versioning.md)
