# Testing Strategy — ToyVision Real-Time

Before connecting a real model, the system must pass mock-detection tests. Logic is built
to be testable with deterministic fake detections (`lib/testing/`).

## Required unit tests

- IoU calculation.
- category validation.
- confidence validation.
- bounding box validation.
- duplicate matching.
- stability counting.
- missing-frame behavior.
- reset behavior.

## Required product (scenario) tests

Driven by `scenario_builders.dart` over `MockToyDetector`:

- one toy visible for several seconds;
- same toy across many frames;
- multiple toys visible;
- toy disappears briefly then returns;
- non-toy object appears;
- person appears;
- camera moves quickly;
- low-light simulation;
- no toys visible;
- pause/resume;
- reset;
- model failure.

## Acceptance criteria

- One toy is counted exactly once.
- The same toy is not counted repeatedly.
- Non-toys are ignored.
- People are ignored.
- Count does not explode with camera movement.
- The app remains responsive.
- Video is not saved by default.

## Testing approach

- Business logic, tracking, and counting are **pure and unit-testable** — no camera or UI
  required.
- The detection engine is swapped via the Strategy pattern; tests use `MockToyDetector`
  and crafted scenarios, never the real model.
- A feature is not done until its unit and relevant product tests exist and pass (see
  [project-operating-system.md](project-operating-system.md) Definition of Done).

## Ownership

Owned by the QA Validation Agent. Guardrail:
[skills/preserve-testing-discipline.md](skills/preserve-testing-discipline.md).
