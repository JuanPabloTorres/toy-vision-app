# Skill: preserve-business-logic

## Purpose
Ensure raw detections are validated before they ever count as toys.

## When to use
Any time you touch `business/`, counting, category rules, or anything that converts
detections into counts.

## Required rules
- Apply all seven validation gates before counting
  ([business-logic-principles.md](../business-logic-principles.md)).
- Use `ToyCategoryRegistry` as the single category source.
- Count stable tracked toys only; set `hasBeenCounted` once counted.
- Read thresholds from `RealtimeDetectionConfig`.
- Treat unknown labels as `unknown` and ignore them.

## Forbidden patterns
- Counting raw detections directly.
- Counting people, pets, or ignored categories.
- Re-counting an already-counted tracked toy.
- Duplicated category maps or inline thresholds.
- Counting on every frame.

## Acceptance criteria
- One toy counts exactly once.
- Ignored objects and people are never counted.
- Counting logic is pure and unit-tested.
- All category truth comes from the registry.
