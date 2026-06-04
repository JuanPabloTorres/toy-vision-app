# Labeling Guidelines — ToyVision Detector

Rules for human labelers producing training data for the ToyVision toy detector.
The detector only **detects**; counting, validity, duplicate identity, and ignored
behavior live in the business layer (`ToyCategoryRegistry`, `ToyDetectionRules`,
`ToyTrackingEngine`, `ToyCountingService`). Label accordingly.

Cross-references:
- [class-taxonomy.md](class-taxonomy.md) — canonical class list and definitions.
- [privacy-rules.md](privacy-rules.md) — what must never be labeled.

## Iron rules

- **Do not guess.** If unsure, label `unknown` or skip the frame.
- **Tight, axis-aligned bounding boxes**, fully inside the frame. No rotated boxes.
- **One label per object instance.** No overlapping boxes for the same object.
- **No people, pets, faces, or children.** Even if visible, they are ignored
  categories and must never be added as toy detections. See
  [privacy-rules.md](privacy-rules.md).
- **No identity labels.** Never tag a specific child, person, or pet.
- **Only the canonical class list** from [class-taxonomy.md](class-taxonomy.md)
  is allowed. Mismatched labels are rejected at import.

## Canonical classes (model index 0..n)

`toy_car, toy_truck, doll, stuffed_animal, building_blocks, ball, action_figure,
toy_train, puzzle, board_game, not_toy, person, pet, book, unknown`.

`person`, `pet`, and `book` exist as **ignored** classes — they are only labeled
when the project explicitly opts into negative-class collection for that batch.
Default: do not draw boxes on them.

## Bounding box rules

- Tight to the visible silhouette of the object. No extra padding.
- Axis-aligned (no rotation). If the toy is tilted, still draw an axis-aligned
  box around its extent.
- Fully inside the frame. If the box would extend past the image edge, clip to
  the edge.
- Minimum size: `≥ 1%` of the frame area. Smaller than that → skip.
- A box must enclose **one** object instance only.

## Scenario rules

### One toy in frame

- One tight box, one canonical label.
- If the object is ambiguous between two classes (e.g. `toy_car` vs `toy_truck`),
  see [Toy cars / trucks / trains](#toy-cars--trucks--trains) below.

### Multiple toys

- One box per toy. Do not merge.
- Order does not matter; the trainer does not depend on label order.

### Overlapping toys

- Label each visible toy with its own box, even if boxes overlap.
- Each box is the full extent of its toy as if the other were not there, **but
  clipped to what is actually visible**. Do not invent occluded geometry.
- If two toys are so fused that you cannot tell where one ends and the next
  begins, label `unknown` for the fused blob and skip individual boxes.

### Partially hidden toys

- If `≥ 50%` of the toy is visible **and** the class is still obvious → label
  normally with a tight box around the visible portion.
- If `< 50%` visible → skip the object. Do not guess the class from a sliver.
- Never extend the box past the visible pixels to "complete" the hidden part.

### Toy piles

- If you can clearly identify `≥ 3` individual toys at the top of the pile,
  label them individually. Do not label the pile.
- If toys are fused into a heap where individual instances cannot be reliably
  separated, draw **one** box around the pile and label `unknown`. Do not
  invent a `toy_pile` class — it is not in the taxonomy.
- Never mix: either label individuals, or label the pile blob as `unknown`.
  Never both for the same region.

### Building blocks

- **Single loose piece** → `building_blocks`, one tight box.
- **A built structure** (assembled blocks forming a single object) → one box
  around the whole structure, label `building_blocks`. Do not box each piece.
- **Scattered loose pieces** (clearly separated) → one box per piece, each
  labeled `building_blocks`, as long as each piece meets the minimum size rule.
- A mix of structure + loose pieces → box the structure once, and box each
  qualifying loose piece separately.

### Board games

Pick exactly one rule per frame, in this priority:

1. If the **box** (closed packaging) is the dominant object → one box around the
   game box, label `board_game`.
2. Else if the **board** is laid out and dominant → one box around the board,
   label `board_game`.
3. Else if only **loose pieces** are visible (cards, tokens, dice) → skip the
   frame. Individual board-game pieces are not in the taxonomy and must not be
   labeled `board_game`.

Never label more than one of {box, board, pieces} as `board_game` in the same
frame.

### Dolls

- `doll` covers human-form figures intended for nurturing/role-play (e.g.
  baby dolls, fashion dolls).
- A plush human-shaped toy is `stuffed_animal` if it is plush, `doll` if it is
  hard-bodied. When in doubt → `unknown`.
- Do not label a child holding a doll. Box only the doll.

### Action figures

- `action_figure` covers articulated character figures (superheroes, soldiers,
  posable characters).
- Boundary with `doll`: if it is articulated and represents a character →
  `action_figure`. If it is a soft/baby/fashion humanoid → `doll`.
- Vehicles that come with action figures are labeled by **vehicle** class
  (`toy_car`, `toy_truck`, `toy_train`), not by the figure.

### Balls

- Any spherical play object → `ball`, regardless of size or sport.
- Do not label real sports equipment that is clearly not a toy (e.g. a
  full-size basketball in an athletic context) → `not_toy` only when visually
  toy-like; otherwise skip.

### Toy cars / trucks / trains

Distinguish only when the form is unambiguous:

- `toy_car` — passenger-car silhouette (sedan, sports car, hatchback).
- `toy_truck` — visible truck bed, cab-over-engine, or large wheels indicating
  a truck/SUV/construction vehicle.
- `toy_train` — locomotive or rail-car form, on or off track.

If the silhouette is ambiguous between car and truck → default to `toy_car`.
Buses, vans, and emergency vehicles → `toy_truck`.
If you cannot tell at all → `unknown`.

### Objects that are not toys but look like toys

- Use `not_toy` **only** when the object is visually toy-like (e.g. a decorative
  figurine, a real fruit shaped like a toy, a baby-product that resembles a
  rattle but isn't sold as a toy).
- Use `not_toy` for items the model is likely to false-positive on. This is a
  **negative class** — it teaches the detector what to reject.
- Do not use `not_toy` for plainly non-toy objects (a TV, a chair, a coffee
  cup). Those are out-of-distribution and should be left unlabeled.

### Uncertain objects

- `unknown` is the safe label for:
  - Object class cannot be determined.
  - Object is too small / blurry / occluded to classify.
  - A fused toy pile that cannot be separated.
- `unknown` boxes are not counted at runtime — see
  [class-taxonomy.md](class-taxonomy.md). They still help the detector learn
  "something is here" without committing to a class.
- Prefer `unknown` over a wrong guess. Always.

## Ignored categories — never label as toys

Per project constraints, these categories are **never** counted and must not
appear as toy detections:

`person, pet, shoe, clothes, bottle, cup, furniture, bed, pillow, phone,
remote_control, book, unknown` (when treated as ignored).

Faces and children are categorically off-limits. See
[privacy-rules.md](privacy-rules.md).

## Labeling QA checklist

Run this before merging a batch of labels. Reject the batch if any item fails.

- [ ] Every label is from the canonical class list in
      [class-taxonomy.md](class-taxonomy.md).
- [ ] No `person`, `pet`, face, or child has been boxed as a toy.
- [ ] All boxes are axis-aligned and fully inside the frame.
- [ ] All boxes are tight to the visible silhouette (no padding, no occluded
      extrapolation).
- [ ] No box smaller than ~1% of the frame.
- [ ] One label per object instance; no duplicate boxes on the same object.
- [ ] Toy-pile rule applied consistently: either individuals **or** one
      `unknown` blob, never both.
- [ ] Board-game rule applied: at most one of {box, board, pieces} labeled
      `board_game` per frame.
- [ ] Partially hidden toys with `< 50%` visibility were skipped, not guessed.
- [ ] Ambiguous cases labeled `unknown` rather than guessed.
- [ ] `not_toy` used only for visually toy-like non-toys, not arbitrary objects.
- [ ] No identity information (names, faces, addresses) present in filenames
      or metadata.

## Out of scope

- Counting, deduplication, and confidence acceptance are **business-layer**
  concerns. Labelers do not enforce them.
- Tracking identity across frames is not a labeling task — see
  `ToyTrackingEngine`.
- Model evaluation and dataset curation are owned by the AI Vision Model Agent.
