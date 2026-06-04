# Class Taxonomy

Defines the canonical class list for the ToyVision detector. The **model class
index order is the contract** between the trained `.tflite` weights, the runtime
loader, and the business layer. Every consumer reads this list in the same
order; changing it without updating both `ToyModelConfig.labels` and
`ToyCategoryRegistry` in the same change will silently mislabel detections.

See also: [../business-logic-principles.md](../business-logic-principles.md),
[../ai-model-guidelines.md](../ai-model-guidelines.md),
[labeling-guidelines.md](labeling-guidelines.md).

## Canonical class order

Indices `0..14`, in the exact order `ToyModelConfig.labels` exposes them and
the order training expects in the label map.

| Idx | Label             | One-line definition                                                   | Counts as toy | Ignored |
| --: | ----------------- | --------------------------------------------------------------------- | :-----------: | :-----: |
|   0 | `toy_car`         | Toy car, racing car, or any small wheeled vehicle (non-truck).        |       yes     |   no    |
|   1 | `toy_truck`       | Toy truck, van, bus, construction vehicle, or large wheeled toy.      |       yes     |   no    |
|   2 | `doll`            | Humanoid doll, fashion doll, or baby doll (non-plush).                |       yes     |   no    |
|   3 | `stuffed_animal`  | Plush toy, teddy bear, or any soft animal/character plush.            |       yes     |   no    |
|   4 | `building_blocks` | LEGO, Duplo, Mega Bloks, wooden blocks, or similar construction set.  |       yes     |   no    |
|   5 | `ball`            | Toy ball of any size or sport type (foam, rubber, plastic).           |       yes     |   no    |
|   6 | `action_figure`   | Articulated figure, superhero, or character toy (non-doll).           |       yes     |   no    |
|   7 | `toy_train`       | Toy train, locomotive, wagon, or train-set piece.                     |       yes     |   no    |
|   8 | `puzzle`          | Jigsaw puzzle, puzzle pieces, or shape-sorter puzzle.                 |       yes     |   no    |
|   9 | `board_game`      | Board game box, board, or board-game pieces.                          |       yes     |   no    |
|  10 | `not_toy`         | Explicit negative — object that is clearly not a toy.                 |       no      |   yes   |
|  11 | `person`          | Human (adult or child); never identified, never counted.              |       no      |   yes   |
|  12 | `pet`             | Cat, dog, or other live animal.                                       |       no      |   yes   |
|  13 | `book`            | Book, magazine, or paper booklet.                                     |       no      |   yes   |
|  14 | `unknown`         | Catch-all for low-confidence or registry-unknown detections.          |       no      |   yes   |

Indices `0..9` are the **toy classes**. Indices `10..14` are **ignored
classes**: the model may emit them, but the business layer drops them before
counting.

## Additional ignored categories

The registry also recognizes these as ignored, but they are **not first-class
model classes** in the current label map. If a future re-train adds them, they
must be appended to the end of `ToyModelConfig.labels` (preserving existing
indices) and registered as ignored in `ToyCategoryRegistry`:

- `shoe`, `clothes`, `bottle`, `cup`, `furniture`, `bed`, `pillow`, `phone`,
  `remote_control`.

Until they exist as trained classes, detections matching these objects will
surface as `unknown` (index 14) and be ignored.

## Sync rule

The model's class index order is a hard contract. A change to **any** of the
following triggers a coordinated update across **all** of them in the same
commit:

1. `ToyModelConfig.labels` — declares the index → label mapping the TFLite
   runtime trusts.
2. `ToyCategoryRegistry` (`lib/business/toy_category_registry.dart`) — declares
   which labels are toys vs. ignored.
3. The trained `.tflite` weights — their head must output classes in the same
   order.
4. This document and the training label map under
   [dataset-plan.md](dataset-plan.md).

`ModelMetadataValidator` enforces at load time that every label in
`ToyModelConfig.labels` is registry-known; a mismatch falls back to
`MockToyDetector` rather than mislabel.

## Never-counted classes

`not_toy` and `unknown` are **registered** so the business layer can recognize
and drop them explicitly, but they **never** contribute to the toy count under
any confidence, tracking, or duplicate-resolution path. They exist to make
"this was detected and intentionally ignored" a first-class outcome rather
than a silent drop.

For borderline cases — half-occluded toys, toy-shaped non-toys, ambiguous
plush vs. doll, etc. — see [labeling-guidelines.md](labeling-guidelines.md).

## Status

- Mock detector remains the default (`toyDetectorModeProvider = mock`).
- TFLite path is behind `ToyDetectorMode.tfliteWithFallback` and only activates
  once a valid model loads and shapes validate.
- Phase 2d physical-device QA is **BLOCKED** (no Android device/emulator
  available). Class taxonomy has not been validated end-to-end on hardware.
