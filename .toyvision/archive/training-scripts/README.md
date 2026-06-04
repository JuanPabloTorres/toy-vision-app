# tools/training/ — Boundary for ML training tooling

This directory is the home for **training-side** scripts and notebooks
that prepare the ToyVision custom toy detector. It is **not** shipped
with the Flutter app and **never** referenced by anything under `lib/`,
`assets/`, or `pubspec.yaml`.

## What lives here

- `dataset/` — local helpers for the Phase 3.9 / 3.10 capture pass.
  Currently present:
  - [`dataset/inspect_raw.ps1`](dataset/inspect_raw.ps1) — read-only
    scanner: counts images per class in `raw/`, lints filenames against
    the canonical `<class>__<tag>__<NNNN>.jpg` pattern, reports
    Day-1 / Day-2 / Day-3 progress vs targets. Pure status; never
    modifies the dataset.
  - [`dataset/import_capture.ps1`](dataset/import_capture.ps1) —
    moves or copies one captured photo from the camera roll into
    `raw/<class>/` with the next available `<NNNN>` counter for the
    given `(class, scene-tag)` pair. Validates the class and tag
    against the allowed sets before writing.
  - [`dataset/detect_duplicates.ps1`](dataset/detect_duplicates.ps1) —
    hashes every `raw/*/*.jpg` with SHA-1 and reports any group of
    bit-identical files. Catches the case where the same source frame
    is imported under two different scene tags. Read-only; you decide
    which copy to keep.
  - [`dataset/verify_dataset.ps1`](dataset/verify_dataset.ps1) — the
    runnable mirror of Gate A in
    [.toyvision/model-training/dataset-validation-checklist.md](../../.toyvision/model-training/dataset-validation-checklist.md).
    Combines layout + filename + duplicate + annotation-pairing +
    canonical-label-in-XML checks. Exits non-zero if any gate fails;
    safe to use as a pre-training gate in a script.

Once Phase 3.8 training begins, this folder will also contain:

- `colab/` — the Colab notebook(s) used to train and export the custom
  detector. Mirrors [.toyvision/model-training/colab-training-plan.md](../../.toyvision/model-training/colab-training-plan.md).
- `inspect/` — optional one-off tools to inspect an exported `.tflite`
  (label list, tensor shapes, hashes).

## How to use the dataset helpers

Both scripts assume PowerShell 7+ (`pwsh`). They default to the local
dataset root `$HOME\toyvision-dataset-v0_1\` but accept a `-Root`
override for alternate locations.

### Check progress and validate filenames

```powershell
# Show Day-1 progress against the priority class targets.
pwsh tools/training/dataset/inspect_raw.ps1

# Show Day-2 or Day-3 progress instead.
pwsh tools/training/dataset/inspect_raw.ps1 -Day 2
pwsh tools/training/dataset/inspect_raw.ps1 -Day 3
```

Read-only. Run it as often as you like during a capture session — it
never moves, renames, or deletes anything. Exits with code 1 if
filename/structure violations are found, 0 otherwise; useful in scripts
or hooks.

### Import one photo

```powershell
# Copy IMG_0042.jpg into raw/toy_car/ as toy_car__floor__<next>.jpg
pwsh tools/training/dataset/import_capture.ps1 `
  -ClassName toy_car -SceneTag floor `
  -SourceFile C:\Users\juanp\Pictures\S25-import\IMG_0042.jpg

# Use -Move to move instead of copy (safer to leave it as copy until you
# trust the choice). Use -WhatIf to dry-run.
pwsh tools/training/dataset/import_capture.ps1 `
  -ClassName stuffed_animal -SceneTag shelf `
  -SourceFile $sourcePath -Move
```

The counter is auto-incremented per `(class, scene-tag)` pair. You
choose the class and scene tag; the script never guesses content. If
the source isn't `.jpg`, or the class/tag aren't in the allowed set,
the script refuses to write.

Privacy is **still your responsibility** before pointing this script
at a file. The script will happily import a photo with a face in it —
it does not look at pixels.

### Find bit-identical duplicates

```powershell
pwsh tools/training/dataset/detect_duplicates.ps1
```

Hashes every `raw/*/*.jpg` and groups any that share SHA-1. Useful if
you suspect the same source frame ended up in two slots. Exits 0 when
no duplicates exist, 1 when any group is found — so it can gate a
training pipeline.

Perceptually-similar but byte-different photos are NOT detected here
(that would need a perceptual-hash tool). This is a defensive check
against accidental re-import, not a curation tool.

### Verify the dataset is trainable

```powershell
pwsh tools/training/dataset/verify_dataset.ps1
pwsh tools/training/dataset/verify_dataset.ps1 -SkipDuplicates
```

Runs every Gate-A check from
[.toyvision/model-training/dataset-validation-checklist.md](../../.toyvision/model-training/dataset-validation-checklist.md):
folder layout, filename lint, exact duplicates, annotation pairing,
and canonical-label-in-XML. Each check reports `PASS` or `FAIL`; exits
0 only if every check passed. Use as the last step before kicking off
Colab training.

The annotation-pairing and canonical-label checks are skipped silently
when `annotations/` and `selected/` are empty (Phase 3.9 / 3.10 capture
sessions). They activate automatically once Phase 3.9.1 (curation) and
Phase 3.9.2 (annotation) start producing files there.

## What is NOT allowed here

- **No images.** No dataset content. The dataset lives outside the repo
  per [.toyvision/model-training/privacy-rules.md](../../.toyvision/model-training/privacy-rules.md).
- **No trained model files.** `.tflite` / `.pt` / `.ckpt` artifacts do
  not live in `tools/`. The validated TFLite asset lands under
  `assets/models/` only after the gates in
  [.toyvision/model-training/export-to-tflite.md](../../.toyvision/model-training/export-to-tflite.md) pass.
- **No app code.** Nothing under `tools/` is referenced from `lib/`,
  imported into Dart, or bundled with the APK. The boundary is hard.
- **No Python runtime invoked at app runtime.** Training is Python /
  Colab. The mobile app is Flutter / Dart only.

## Why a separate folder

Two reasons:

1. **Licence and dependency isolation.** Training tools (TensorFlow,
   MediaPipe Model Maker, etc.) drag in heavy dependencies that have no
   business in the mobile build graph. Keeping them outside `lib/`
   prevents accidental inclusion in the APK.
2. **Privacy isolation.** Training tooling touches real dataset images
   (which never enter the repo). The boundary makes it visually obvious
   when a change strays into territory that should stay out of source
   control.

## Adding content here

When training begins (Phase 3.8 step 4 per
[.toyvision/model-training/flutter-integration-plan.md](../../.toyvision/model-training/flutter-integration-plan.md)
§"Order of operations"):

1. Add `tools/training/colab/toyvision_v0_1.ipynb` (the executed
   notebook, with outputs cleared for review).
2. Add `tools/training/dataset/verify_dataset.py` (the local
   pre-flight check that mirrors Cell 3 of the Colab plan).
3. Record the addition in
   [.toyvision/model-training/model-versioning.md](../../.toyvision/model-training/model-versioning.md).

Anything else (datasets, weights, raw exports) stays out.
