# Dataset Capture Pass — ToyVision Prototype v0.1 (Phase 3.9)

The hands-on field manual for capturing the first 300–500 prototype
images. Pure documentation — **no code changes, no training, no model
placement**. The dataset lives outside the repo.

This doc says **what to do today and tomorrow**. The deeper "why" lives
in:

- [collection-guide.md](collection-guide.md) — capture rules + privacy
  non-negotiables (binding).
- [dataset-plan.md](dataset-plan.md) — sizes, splits, balance targets.
- [dataset-validation-checklist.md](dataset-validation-checklist.md) —
  the gates the captured dataset must clear before training.
- [privacy-rules.md](privacy-rules.md) — non-negotiable privacy bar.
- [class-taxonomy.md](class-taxonomy.md) — the canonical 14-label set.

When this doc and `collection-guide.md` disagree, the privacy and
folder-naming rules in `collection-guide.md` win and this doc gets
updated.

## Goal of the capture pass

> Produce 300–500 annotated images, captured in the room where ToyVision
> will be used, that can train an EfficientDet Lite 0 prototype detector
> able to recognize *some* real toys live on the Galaxy S25.

This is a **prototype** dataset. It is not yet shippable; it exists to
validate that the trained model + Flutter integration can detect
something other than fake mock data on hardware.

## Local folder structure (outside the repo)

Pick a path that is **not** inside this Git repository — e.g. a
`~/datasets/` directory or a private OneDrive / Google Drive folder
synced to a local path. The dataset is never committed and never moved
into `assets/`.

Recommended root: `<home>/toyvision-dataset-v0_1/`.

```text
toyvision-dataset-v0_1/
├── raw/                              # every photo as captured (lossless)
│   ├── toy_car/
│   ├── toy_truck/
│   ├── doll/
│   ├── stuffed_animal/
│   ├── building_blocks/
│   ├── ball/
│   ├── action_figure/
│   ├── toy_train/
│   ├── puzzle/
│   ├── board_game/
│   ├── not_toy/
│   ├── person_no_face/               # only if needed; see "Person rule" below
│   ├── pet/
│   ├── book/
│   ├── negative_only/                # frames with NO toy box (rooms, floors, clutter)
│   └── uncertain_review/             # holding area; do not annotate these yet
├── selected/                         # curated subset chosen for annotation
│   ├── train/
│   ├── val/
│   └── test/
├── annotations/                      # PASCAL VOC .xml output from the labelling tool
│   ├── train/
│   ├── val/
│   └── test/
├── splits/                           # text files listing image stems per split
│   ├── train.txt
│   ├── val.txt
│   └── test.txt
├── capture-log.md                    # one-line entry per capture session
└── dataset-card.md                   # filled from dataset-card-template.md
```

Create with one command (PowerShell on Windows):

```powershell
$root = "$HOME\toyvision-dataset-v0_1"
$classes = @(
  'toy_car','toy_truck','doll','stuffed_animal','building_blocks',
  'ball','action_figure','toy_train','puzzle','board_game',
  'not_toy','person_no_face','pet','book',
  'negative_only','uncertain_review'
)
foreach ($c in $classes) { New-Item -ItemType Directory -Force "$root\raw\$c" | Out-Null }
foreach ($split in 'train','val','test') {
  New-Item -ItemType Directory -Force "$root\selected\$split" | Out-Null
  New-Item -ItemType Directory -Force "$root\annotations\$split" | Out-Null
}
New-Item -ItemType Directory -Force "$root\splits" | Out-Null
New-Item -ItemType File -Force "$root\capture-log.md" | Out-Null
New-Item -ItemType File -Force "$root\dataset-card.md" | Out-Null
Write-Host "Created $root"
```

(Bash equivalent is straightforward; documented above only because the
S25 + Windows environment is what's actually being used.)

### Why `raw/` and `selected/` are separate

- **`raw/`** holds every photo you take, lossless. No deletions, no
  edits — even photos that look "bad" stay here in case they turn out to
  be useful later (a partially-blurred toy is still a real toy box-able
  scene).
- **`selected/`** is the curated subset that will be annotated and used
  for training. Curation is a separate pass after capture, so the raw
  set stays untouched.

This separation costs ~2× disk but protects against accidentally
deleting unique frames.

## Naming convention

Every captured file follows this exact pattern:

```text
<class>__<scene-tag>__<NNNN>.jpg
```

- `<class>` — one of the canonical labels (matches the `raw/` folder
  name). Use the folder name verbatim — no abbreviations.
- `<scene-tag>` — short kebab-case description of the scene context:
  `floor`, `bin`, `shelf`, `mixed`, `occluded`, `lowlight`, `topdown`,
  `closeup`, `farshot`, `lookalike`, `negative`.
- `<NNNN>` — four-digit zero-padded counter, per `(class, scene-tag)`
  pair. Restart at `0001` for each new combination.

Examples:

```text
toy_car__floor__0001.jpg
toy_car__bin__0001.jpg
stuffed_animal__shelf__0007.jpg
ball__lowlight__0003.jpg
building_blocks__mixed__0012.jpg
negative_only__floor__0004.jpg
book__lookalike__0002.jpg
not_toy__closeup__0005.jpg
```

Two separators between tokens (`__`) so the parts are unambiguous when
split by tooling. No spaces, no `(1)` suffixes, no camera default
names like `IMG_20260531_120532.jpg`. Rename before saving.

For images that genuinely contain multiple distinct classes, file under
the **most prominent** class folder and use `mixed` as the scene tag
(the annotation step covers the secondary classes via separate
bounding boxes in the same image).

## Per-class capture targets (prototype v0.1)

Aim for these counts in `raw/`. Curation in `selected/` will drop some
to hit the 300–500 final.

| Class | Raw target | Notes |
| --- | --- | --- |
| `toy_car` | 40–60 | At least 2 distinct cars; varied colors |
| `toy_truck` | 40–60 | At least 2 distinct trucks |
| `doll` | 40–60 | At least 2 distinct dolls |
| `stuffed_animal` | 40–60 | At least 3 distinct plushes; varied sizes |
| `building_blocks` | 40–60 | Loose pieces + a built shape; varied colors |
| `ball` | 40–60 | At least 2 sizes |
| `action_figure` | 30–50 | At least 2 distinct figures |
| `toy_train` | 30–50 | Engine or full train both OK |
| `puzzle` | 30–50 | Mid-assembly + scattered pieces |
| `board_game` | 20–40 | Box (closed) + pieces on table |
| `not_toy` | 30–50 | Common confusables: pillow, cup, real car key, real shoe |
| `book` | 20–30 | Confusable with `board_game` |
| `pet` | 0–20 | Only if a pet exists; never identifiable faces of owners nearby |
| `person_no_face` | 0–20 | Only if needed for the model to learn to ignore; see below |
| `negative_only` | 30–50 | Empty rooms / floors / clutter — NO toy in frame |

Per-class minimums (must hit, not just target): see Gate B in
[dataset-validation-checklist.md](dataset-validation-checklist.md).

## Variation matrix (per class)

Each toy class needs spread across **all four** axes below. Use the
file's `<scene-tag>` to encode it. The whole class set should cover the
matrix; not every photo needs every axis.

| Axis | Required tags |
| --- | --- |
| Background | `floor`, `bin`, `shelf` (at least 5 each per class) |
| Composition | `closeup`, `farshot`, `mixed` (at least 3 each per class) |
| Occlusion | `occluded` (at least 5 per class — 25–75% hidden) |
| Lighting | `lowlight` (at least 5 per class — lamp / evening) |
| Confusables | `lookalike` (at least 3 of `not_toy` / `book` per class set) |

This matrix matches Gate C in
[dataset-validation-checklist.md](dataset-validation-checklist.md).

## The `person_no_face` rule

The model must learn to ignore people. The training data therefore
needs *some* images containing people — but **never with a face in
frame**.

**Allowed in `person_no_face/`:**

- Torso-down shots of an adult (legs, hands, feet) where no face is
  visible.
- Adult wearing plain clothing — no name tags, no logos that identify a
  workplace or school.
- The project owner deliberately framing themselves with face out of
  frame.

**Never in `person_no_face/`:**

- Any image of a child. Whole-image discard. Children do not appear in
  this dataset, period.
- Any face — even partial, even of an adult.
- Any identifying clothing, uniform, or accessory.
- Anyone other than the project owner without prior written consent.

If a person appears unexpectedly in the frame: discard the photo or
crop them out completely before saving. Do not "fix it later".

## Per-image acceptance — the 5-second snap test

Before saving, eyeball the photo and confirm **all five** in under 5
seconds. If any fails, delete the photo and re-shoot.

1. **One clear class fits**, or it belongs in `uncertain_review/` (do
   not force a label).
2. **No faces, no children, no private info** in the frame
   (mail, addresses, screen contents, ID badges).
3. **Focus is good enough** to recognize the toy — pixelated /
   smeared-by-motion shots go in `uncertain_review/` if you might still
   want them, otherwise delete.
4. **Filename matches the naming convention** before saving (rename
   the camera default at save time, not later in batch).
5. **The toy occupies somewhere between 3% and 70% of the frame.**
   Truly tiny dots or full-frame-filling toys teach the model the
   wrong thing — neither extreme is realistic for the live use case.

## Reject criteria — discard immediately

Don't move these to `uncertain_review/`. Delete them.

- Any face, any age, even partial.
- Any child, any body part of a child.
- Private documents, mail, screens with personal information.
- Identifying home features (house number, plate number, name tags).
- Pictures of pictures, screen photos, or any image you didn't capture
  yourself.
- Blurred beyond recognition AND no recoverable scene context.
- Duplicate-of-duplicate-of-duplicate (a burst of 20 nearly identical
  shots — keep 2–3 representative frames).
- Any image you don't have the right to use (someone else's photo, a
  download, a thumbnail).

## Daily plan

The pass is structured across three short sessions so the work doesn't
collapse into one tired-marathon day.

### Day 1 — 100 raw images, easy classes first

Target classes (per the user's "what to shoot first"):

1. `toy_car` — ~25 images
2. `stuffed_animal` — ~25 images
3. `ball` — ~20 images
4. `building_blocks` — ~15 images
5. `book` (lookalike) — ~10 images
6. `not_toy` / `negative_only` — ~5 images

End of Day 1 deliverable:

- 100 images in `raw/` across 6 folders.
- One `capture-log.md` line for Day 1 (devices used, lighting,
  duration, rough class counts).
- A glance at the `dataset-card.md` template — start filling the
  identification fields.

### Day 2 — bring to 200 raw images, fill out the toy classes

Target classes:

1. `doll` — ~20 images
2. `action_figure` — ~15 images
3. `toy_truck` — ~20 images
4. `toy_train` — ~15 images
5. Round out Day 1 classes that came in light — `toy_car`,
   `stuffed_animal` typically need more variation
6. Add a first `mixed` batch — 10–15 images of 2+ toys together

End of Day 2 deliverable:

- 200 images total in `raw/`.
- All 10 toy classes have at least *some* raw images (even if a few
  are below their final target).
- `capture-log.md` updated with Day 2 line.

### Day 3 — bring to 300–500 raw, hit the variation matrix

Target classes:

1. `puzzle` — ~20 images
2. `board_game` — ~15 images
3. `pet` if applicable — up to 20 images
4. `person_no_face` if needed and safe — up to 20 images
5. Fill the variation axes for any class still thin
   (`occluded`, `lowlight`, `lookalike`)
6. `mixed` — bring multi-toy images to at least 50 total

End of Day 3 deliverable:

- 300–500 images total in `raw/`.
- Variation matrix gates met (Gate C in
  [dataset-validation-checklist.md](dataset-validation-checklist.md)).
- `capture-log.md` complete with three session entries.
- `dataset-card.md` filled in.
- Curate `selected/` from `raw/` (Day 4 work) — this is the next pass,
  not this one.

## After Day 3 — what happens next (not this phase)

Phase 3.9 ends when Day 3 deliverables are met. The next phases are:

- **Phase 3.9.1 — Curation pass.** Move chosen frames from `raw/` to
  `selected/{train,val,test}/` per the 70/15/15 split. Held-out
  unseen-toy specimen goes in `test/`.
- **Phase 3.9.2 — Annotation pass.** Open the selected frames in
  CVAT / LabelImg / Label Studio; produce one `.xml` per image in
  `annotations/{train,val,test}/`.
- **Phase 3.9.3 — Dataset validation.** Run the programmatic gates in
  [dataset-validation-checklist.md](dataset-validation-checklist.md)
  against the annotated dataset. Block on any failure.
- **Phase 3.10 — Training.** Colab notebook per
  [colab-training-plan.md](colab-training-plan.md).

None of those start until Phase 3.9 is complete. The current ToyVision
app on the Galaxy S25 stays in `mock` (default) / `mlkitWithFallback`
(opt-in) modes; no Flutter code changes, no `tflite_flutter` returns,
no `assets/models/` placement.

## What this phase deliberately does NOT do

- No `lib/`, `android/`, `ios/`, `pubspec.yaml`, or `assets/models/`
  changes. **Verified:** Phase 3.9 only touches
  `.toyvision/model-training/` and adds an external dataset folder
  outside the repo.
- No training. No model export. No model placement.
- No upload of any image to a third-party service.
- No commit of any image, annotation, or `dataset-card.md` to this
  repository.
- No widening of the canonical 14-label set. Anything that doesn't fit
  goes in `uncertain_review/` (to think about later) or `not_toy/`
  (if it's a clear non-toy that looks toy-like).

## Local helpers (Phase 3.10)

Two PowerShell scripts under
[`tools/training/dataset/`](../../tools/training/dataset/) take the
manual work out of counting + numbering during a capture session.
Both are read-only / single-file write only; neither touches the app or
the repo's source code.

### `inspect_raw.ps1` — see progress

```powershell
pwsh tools/training/dataset/inspect_raw.ps1            # Day 1 targets
pwsh tools/training/dataset/inspect_raw.ps1 -Day 2     # Day 2 targets
pwsh tools/training/dataset/inspect_raw.ps1 -Day 3     # Day 3 targets
```

Reports counts per class, flags filename violations, and shows progress
against the Day-N target table. Run as often as you like during a
session — it never modifies the dataset.

### `import_capture.ps1` — drop one photo into the right slot

```powershell
pwsh tools/training/dataset/import_capture.ps1 `
  -ClassName toy_car -SceneTag floor `
  -SourceFile C:\Users\juanp\Pictures\S25-import\IMG_0042.jpg
```

Picks the next `<NNNN>` for the `(class, scene-tag)` pair and copies
(or moves with `-Move`) the source file into `raw/<class>/` as
`<class>__<scene-tag>__<NNNN>.jpg`. You still decide the class and
scene tag — the script doesn't infer either from the image content.

## End-of-session checklist (run after each day)

- [ ] Every photo from today has a valid filename per §"Naming
      convention".
- [ ] No file landed in the wrong class folder (sanity-glance the
      thumbnails).
- [ ] `uncertain_review/` has been re-checked once — anything obvious
      moved to its proper class, the rest left as-is.
- [ ] Today's session has a one-line entry in `capture-log.md`:
      date, duration, devices used, lighting conditions, rough counts
      per class, any privacy near-misses (and what was discarded).
- [ ] No photo from today is on a third-party cloud you didn't choose
      (auto-upload to Google Photos, iCloud, etc. is disabled on the
      capture device, or the photos have been moved out of the
      sync folder).
- [ ] The disk where `toyvision-dataset-v0_1/` lives has at least 2 GB
      free (a 500-image set with raw photos can easily hit 1 GB).
- [ ] Mind clear that no child appeared in any photo from today. If
      uncertain, glance through every Day-N image before closing the
      session.
