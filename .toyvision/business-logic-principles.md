# Business Logic Principles — ToyVision Real-Time

A raw detection is **not** automatically a toy. Business logic — never the model, never
the UI — decides what counts.

## Toy validation gate

A detection counts as a toy only if **all** of these are true:

1. label exists in `ToyCategoryRegistry`;
2. that category has `countsAsToy = true`;
3. confidence is at or above the category's minimum confidence;
4. the bounding box is valid (within frame, positive width/height, sane area);
5. the object appears for enough stable frames (`minimumStableFrames`);
6. the object is not a duplicate of an already-counted tracked toy;
7. the object is not a person, pet, or otherwise ignored object.

## Toy categories (initial)

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
```

## Ignored / negative categories

These must never be counted and (by default) never shown to normal users:

```text
person
pet
shoe
clothes
bottle
cup
furniture
bed
pillow
phone
remote_control
book
unknown
```

## Toy category registry contract

`ToyCategoryRegistry` is the single source of category truth. Each entry defines:

- `label` — the model/raw label key;
- `displayName` — user-facing name;
- `countsAsToy` — boolean;
- `minimumConfidence` — per-category threshold;
- `isIgnored` — boolean;
- `uiDisplayBehavior` — how/whether it renders.

No other file may define a parallel category map. Changing a model label requires
updating this registry in the same change.

## Default thresholds

These live in `RealtimeDetectionConfig`, never inline:

```text
minimumStableFrames = 3
maximumMissingFrames = 10
iouMatchThreshold    = 0.45
targetInferenceFps   = 5 to 10
```

## Counting rule

- **Never count every frame.** Count stable, tracked toys.
- Once a tracked toy has been counted, set `hasBeenCounted = true` so it is never
  re-counted while it remains tracked.
- A toy missing for more than `maximumMissingFrames` is dropped from tracking; if it
  reappears it is matched by tracking logic, not blindly re-counted.

## Ownership

This logic lives in the Business Logic Layer (`lib/business/`) and is owned by the
Business Logic Agent. Guardrail: [skills/preserve-business-logic.md](skills/preserve-business-logic.md).
