# Dataset Collection Guide

A focused, action-oriented checklist for collecting the prototype dataset.
Use this in parallel with [dataset-plan.md](dataset-plan.md) (which goes
deeper on sizes, splits, and coverage). Nothing here authorizes training,
exporting, or uploading anything; it only describes how to take photos.

## Rules in one line

> No rostro, no niño identificable, no información privada, no uploads, no
> entrenamiento.

If those rules can't be met for a given photo, **discard it**.

## Local-only folder tree

Keep the dataset **outside the repo** (or in a gitignored path). Never commit
photos.

```
toyvision-dataset-prototype/
├── toy_car/
├── toy_truck/
├── doll/
├── stuffed_animal/
├── building_blocks/
├── ball/
├── action_figure/
├── toy_train/
├── puzzle/
├── board_game/
├── not_toy/
├── uncertain_review/
└── negative_examples/
    ├── pet/
    ├── shoe/
    ├── book/
    ├── pillow/
    ├── cup/
    └── remote_control/
```

- **One class per folder.** Folder names match the canonical labels in
  [class-taxonomy.md](class-taxonomy.md) — do not rename.
- **`uncertain_review/`** is a holding area for dubious photos. Do not label
  these yet; review them in batch later. Forcing a label here pollutes the
  dataset.
- **`not_toy/`** is for objects that are clearly *not* a toy but were tempting
  to label as one (look-alike confusion).
- **`negative_examples/`** are for hard negatives the model needs to learn to
  ignore (pet/shoe/book/pillow/cup/remote_control). **No `person/` folder** —
  if a person appears, discard the photo or crop them out before saving.

## What every batch of photos should cover

Aim to spread coverage across these axes; you don't need every combination per
class, but the dataset as a whole should hit each item.

- Toys alone.
- Toys mixed together (multiple classes in one frame).
- Toys on the floor.
- Toys in a toy box / bin.
- Toys on a shelf.
- Toys partially covered (under a blanket, behind another object).
- Low light (evening lamp).
- Normal indoor daylight.
- Multiple angles per toy (front, oblique, top).
- Different distances (close-up, mid, far).
- Cluttered real backgrounds (rug, play-mat).
- Look-alike negatives that frequently confuse detectors (pillow vs stuffed
  animal, cup vs ball, book vs board_game box, remote_control vs toy_truck).

## Privacy non-negotiables

- **No child faces.** Ever. Even if the child is your own and consents — children
  cannot meaningfully consent for training data.
- **No identifiable adults** (faces, distinctive clothing, name tags) without
  written consent of that adult. Prefer not photographing people at all.
- **No private documents, screens with personal data, mail, IDs, addresses.**
- **No identifiable home info** (house number visible through a window, etc.)
  where avoidable.
- If a person appears accidentally: **discard or crop**. Do not place into a
  `negative_examples/person/` folder.
- **No uploads to third-party labeling/training services** without explicit
  consent. Use local or self-hosted tools.

These extend the app-level guarantees in
[../privacy-safety-guidelines.md](../privacy-safety-guidelines.md). The
training pipeline must respect them as strictly as the runtime does.

## Per-photo capture checklist

Before saving a photo, confirm:

- [ ] One clear class fits the photo (or it goes in `uncertain_review/`).
- [ ] No faces, no identifiable children, no private info visible.
- [ ] Reasonable focus (not blurred beyond recognition unless that's the point).
- [ ] Filename is descriptive: `<class>_<short-tag>_<NNN>.jpg`
      (e.g. `toy_car_floor_001.jpg`).

## What NOT to do in this phase

- Do **not** train a model.
- Do **not** export anything.
- Do **not** place files anywhere under `assets/models/`.
- Do **not** upload photos to third-party tools.
- Do **not** commit photos to this repository.
- Do **not** alter app code, business rules, or detectors.

See also: [dataset-plan.md](dataset-plan.md),
[labeling-guidelines.md](labeling-guidelines.md),
[privacy-rules.md](privacy-rules.md).
