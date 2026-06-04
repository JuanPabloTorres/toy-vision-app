# Colab Training Plan — ToyVision Custom Detector (Phase 3.8)

Step-by-step plan for training the first ToyVision custom toy detector in
Google Colab using **MediaPipe Model Maker** for Object Detection,
exporting to TFLite, and downloading the artifact for app integration.

This document is **execution guidance**, not yet executed. Training only
begins when the prototype dataset clears
[dataset-validation-checklist.md](dataset-validation-checklist.md).

Sibling docs:

- [custom-detector-strategy.md](custom-detector-strategy.md) — why MediaPipe
  Model Maker; why EfficientDet Lite 0; what is gated.
- [training-pipeline.md](training-pipeline.md) — class label set, input
  contract, output contract.
- [dataset-validation-checklist.md](dataset-validation-checklist.md) —
  pre-training quality bar.
- [export-to-tflite.md](export-to-tflite.md) — post-training validation
  gates.
- [flutter-integration-plan.md](flutter-integration-plan.md) — app-side
  integration after the `.tflite` is produced.
- [privacy-rules.md](privacy-rules.md) — what may and may not appear in
  the dataset.
- [model-versioning.md](model-versioning.md) — what must be recorded
  before any export is placed in the app.

## Environment

- **Runtime:** Google Colab, **GPU runtime**. Free-tier T4 is sufficient
  for EfficientDet Lite 0 on a 300–500 image prototype dataset (~30–60
  minutes of training).
- **Python:** 3.10 (Colab default at time of writing).
- **Library:** `mediapipe-model-maker` (Apache-2.0). Pin the exact
  version in the notebook header and record it per
  [model-versioning.md](model-versioning.md).
- **Dataset hosting:** Private Google Drive folder shared only with the
  project owner. The dataset is **not** committed to this repository
  (`.gitignore` blocks `datasets/`). No third-party cloud upload of raw
  images.

## Notebook structure

The notebook lives outside this repo, in the same private Google Drive
folder that hosts the dataset. It has the following ordered cells:

### Cell 1 — Header and version pinning

A markdown cell records:

- Notebook version (semver).
- Author + date.
- `mediapipe-model-maker` target version.
- Dataset snapshot identifier (the Drive folder name + date).
- Hash of the dataset manifest (if one exists).

Followed by a code cell that pins the install:

```python
!pip install -q mediapipe-model-maker==<PINNED_VERSION>
import mediapipe_model_maker
print('mediapipe-model-maker', mediapipe_model_maker.__version__)
```

The printed version is copied back into the markdown cell and recorded
per [model-versioning.md](model-versioning.md). A version drift between
runs invalidates the export.

### Cell 2 — Mount the dataset

```python
from google.colab import drive
drive.mount('/content/drive')
```

The dataset folder structure on Drive must already match the layout in
[training-pipeline.md](training-pipeline.md) §1:

```
datasets/toyvision/
  train/ images/  annotations/
  val/   images/  annotations/
  test/  images/  annotations/
```

If the structure is different, **fix the dataset on Drive, not the
notebook**. The notebook reads from the canonical layout only.

### Cell 3 — Verify dataset before training

A short verification cell that runs the
[dataset-validation-checklist.md](dataset-validation-checklist.md)
programmatic checks (image count per class, missing annotation files,
labels outside the canonical 14 set, etc.). If any check fails, the
cell **raises** and training is blocked. Concrete example:

```python
from pathlib import Path
import xml.etree.ElementTree as ET

CANONICAL_LABELS = {
    'toy_car', 'toy_truck', 'doll', 'stuffed_animal', 'building_blocks',
    'ball', 'action_figure', 'toy_train', 'puzzle', 'board_game',
    'not_toy', 'person', 'pet', 'book',
}

def verify_split(split_dir: Path):
    images = sorted(p.stem for p in (split_dir / 'images').glob('*.jpg'))
    annots = sorted(p.stem for p in (split_dir / 'annotations').glob('*.xml'))
    assert images == annots, (
        f'image/annotation mismatch in {split_dir.name}: '
        f'images={len(images)} annots={len(annots)}'
    )
    seen = set()
    for xml in (split_dir / 'annotations').glob('*.xml'):
        for name in ET.parse(xml).getroot().iter('name'):
            seen.add(name.text)
    extras = seen - CANONICAL_LABELS
    assert not extras, f'unknown labels in {split_dir.name}: {extras}'
    return len(images), seen

for split in ['train', 'val', 'test']:
    n, labels = verify_split(Path('/content/drive/MyDrive/datasets/toyvision') / split)
    print(f'{split}: {n} images, {len(labels)} labels')
```

A failing assertion stops the notebook. The dataset must be fixed on
Drive and the cell re-run.

### Cell 4 — Load the datasets

```python
from mediapipe_model_maker import object_detector

DATA_ROOT = '/content/drive/MyDrive/datasets/toyvision'
CACHE_ROOT = '/tmp/od_cache'

train_data = object_detector.Dataset.from_pascal_voc_folder(
    f'{DATA_ROOT}/train',
    cache_dir=f'{CACHE_ROOT}/train',
)
val_data = object_detector.Dataset.from_pascal_voc_folder(
    f'{DATA_ROOT}/val',
    cache_dir=f'{CACHE_ROOT}/val',
)
print('train size:', train_data.size)
print('val size:', val_data.size)
```

Cache the parsed dataset under `/tmp` so re-runs are fast. The cache is
disposable and not exported.

### Cell 5 — Configure training options

```python
spec = object_detector.SupportedModels.EFFICIENTDET_LITE0

# Pin every hyperparameter. Reproducing the run requires the same values.
hparams = object_detector.HParams(
    learning_rate=0.3,
    batch_size=8,
    epochs=50,
    cosine_decay_epochs=50,
    cosine_decay_alpha=0.0,
    export_dir='/content/exported',
)
options = object_detector.ObjectDetectorOptions(
    supported_model=spec,
    hparams=hparams,
)
```

The Phase 3.8 prototype starts with the MediaPipe defaults above. Targets
are deliberately conservative — the prototype proves the pipeline works,
not that the model is shippable.

### Cell 6 — Train

```python
model = object_detector.ObjectDetector.create(
    train_data=train_data,
    validation_data=val_data,
    options=options,
)
```

Expected runtime on a free-tier T4 with 300–500 prototype images and 50
epochs: roughly 30–60 minutes. Watch for these warning signs in the
training log and stop early if any appear:

- Validation mAP plateaus at < 0.10 for ≥ 10 epochs → dataset is too
  small or labels are inconsistent; fix the dataset, do not push training
  further.
- NaN loss → reduce learning rate, re-run.
- One class dominates the train set → rebalance per
  [dataset-plan.md](dataset-plan.md).

### Cell 7 — Evaluate

```python
metrics = model.evaluate(val_data)
print(metrics)
```

Record every metric reported (AP, AP50, AP75, APs, APm, APl, plus per-class
breakdowns) and append them to the version-record block (Cell 10). A
prototype run is **not gated** on hitting the production thresholds — the
gates from [custom-detector-strategy.md](custom-detector-strategy.md) §11
apply to default-promotion, not opt-in shipment for QA. Recording the
gap is the point.

### Cell 8 — Export to TFLite

```python
EXPORT_NAME = 'toy_detector_v0_1.tflite'
model.export_model(EXPORT_NAME)

import os, hashlib
exported = os.path.join('/content/exported', EXPORT_NAME)
assert os.path.exists(exported), f'export missing: {exported}'
size = os.path.getsize(exported)
with open(exported, 'rb') as f:
    sha = hashlib.sha256(f.read()).hexdigest()
print('exported file:', exported)
print('size bytes:', size)
print('sha256:', sha)
```

The printed `size`, `sha`, and label list (from Cell 9) are copied into
the [model-versioning.md](model-versioning.md) entry before the file
leaves Colab.

### Cell 9 — Inspect the exported metadata

```python
from tflite_support import metadata

displayer = metadata.MetadataDisplayer.with_model_file(exported)
print('metadata json:')
print(displayer.get_metadata_json())
print('label files:', displayer.get_packed_associated_file_list())
for name in displayer.get_packed_associated_file_list():
    print(f'\n--- {name} ---')
    print(displayer.get_associated_file_buffer(name).decode('utf-8'))
```

This must print the canonical 14-label list and the input normalization
parameters (`mean=127.5`, `std=127.5`). If the metadata is empty or
diverges, the export fails Gate 2 in
[export-to-tflite.md](export-to-tflite.md). Do not proceed.

### Cell 10 — Version record block

A markdown cell with the values to copy into
[model-versioning.md](model-versioning.md):

```text
version: v0.1.0
date: <YYYY-MM-DD>
notebook_hash: <git-tracked notebook commit OR file sha256>
mediapipe_model_maker_version: <pinned>
dataset_snapshot: <Drive folder name + date>
hparams:
  learning_rate: 0.3
  batch_size: 8
  epochs: 50
  cosine_decay_epochs: 50
  cosine_decay_alpha: 0.0
metrics:
  AP:    <value>
  AP50:  <value>
  AP75:  <value>
  per_class:
    toy_car: { precision: ..., recall: ... }
    toy_truck: { precision: ..., recall: ... }
    ...
export:
  file: toy_detector_v0_1.tflite
  size_bytes: <value>
  sha256: <value>
  labels: [toy_car, toy_truck, doll, stuffed_animal, building_blocks, ball,
           action_figure, toy_train, puzzle, board_game, not_toy, person,
           pet, book]
```

### Cell 11 — Download

```python
from google.colab import files
files.download(exported)
```

The downloaded file is then committed to the app repo at
`assets/models/toy_detector_v0_1.tflite` **only after** the gates in
[export-to-tflite.md](export-to-tflite.md) pass. Before placement, the
file size and SHA-256 must match the values from Cell 8.

## What is intentionally NOT in the notebook

- **No code that reads identifying metadata from images.** No face
  detection. No EXIF GPS scrubbing — the dataset is captured without GPS
  by policy, not by post-processing.
- **No upload of images to a third-party service.** Drive is the
  exclusive host; no Hugging Face, Roboflow, or public sharing.
- **No automated dataset augmentation that could merge two children's
  images.** Augmentation runs per-image (rotation, brightness, mild crop)
  and stays within the project owner's controlled dataset.
- **No code path that re-routes the export to a remote URL.** The export
  download is interactive (`files.download`) — there's no
  "auto-upload-on-export" wire.

## When training is allowed

Training is **blocked** until **all** of the following are true:

1. The prototype dataset (300–500 images, 14 classes per
   [training-pipeline.md](training-pipeline.md) §7) is staged on Drive.
2. The
   [dataset-validation-checklist.md](dataset-validation-checklist.md)
   programmatic checks (Cell 3) pass.
3. The privacy review in [privacy-rules.md](privacy-rules.md) is signed
   off by the project owner for this dataset snapshot.
4. The pinned `mediapipe-model-maker` version is recorded in
   [model-versioning.md](model-versioning.md) (Phase 3.8 version-record
   entry exists).

Otherwise the notebook stops at Cell 3 and the rest is not executed.
