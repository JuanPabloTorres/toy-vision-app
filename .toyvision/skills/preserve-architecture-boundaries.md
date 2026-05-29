# Skill: preserve-architecture-boundaries

## Purpose
Keep each layer responsible for exactly one thing, with one-way data flow.

## When to use
Any time you add or move code between `camera/`, `detection/`, `tracking/`, `business/`,
`ui/`, `storage/`, or the model layer.

## Required rules
- Place code in the layer that owns its responsibility
  ([architecture-principles.md](../architecture-principles.md)).
- Keep data flow one-way: Camera → Detection → Tracking → Business → State → UI.
- Share cross-layer helpers via `core/`, never by duplication.
- Keep thresholds in `RealtimeDetectionConfig` only.

## Forbidden patterns
- Counting, IoU, or validation in UI/painters.
- Inference inside widgets.
- Business layer reading camera frames or drawing UI.
- Tracking layer storing permanent history.
- A lower layer reaching up into the UI.

## Acceptance criteria
- Each touched file stays within its layer's responsibility.
- No duplicated logic across layers.
- Thresholds are centralized.
- Data flows in one direction only.
