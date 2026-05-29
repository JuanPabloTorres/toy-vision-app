# Skill: preserve-testing-discipline

## Purpose
Ensure every feature has unit and product validation before it is considered done.

## When to use
Any time you add or change logic in `business/`, `tracking/`, the detection rules, or the
counting flow.

## Required rules
- Cover required unit tests: IoU, category/confidence/bbox validation, duplicate
  matching, stability counting, missing-frame behavior, reset
  ([testing-strategy.md](../testing-strategy.md)).
- Add relevant product scenarios via `scenario_builders.dart` over `MockToyDetector`.
- Keep business/tracking/counting logic pure and testable without UI or camera.
- Confirm all acceptance criteria hold.

## Forbidden patterns
- Shipping logic without tests.
- Tests that depend on the real model or network.
- Untested counting/duplicate behavior.
- Marking a feature done with failing or partial tests.

## Acceptance criteria
- One toy counts once; the same toy is not re-counted.
- Non-toys and people are ignored.
- Count does not explode on camera movement.
- Required unit and product tests exist and pass.
