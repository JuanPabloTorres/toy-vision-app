# Development Methodology — ToyVision Real-Time

## Per-task cycle

Every task, no matter how small, follows this cycle:

1. **Understand the product rule** — read the relevant governance file(s).
2. **Identify the responsible agent** — see [agent-routing.md](agent-routing.md).
3. **Apply the relevant skills** — see [skills/](skills/).
4. **Propose a minimal plan** — smallest change that satisfies the rule.
5. **Implement only the necessary layer** — respect boundaries.
6. **Add or update tests** — see [testing-strategy.md](testing-strategy.md).
7. **Validate architecture boundaries** — no logic leaked across layers.
8. **Document decisions** — when system behavior changes.

## Minimal-change discipline

- A bug fix does not need surrounding cleanup.
- A one-shot operation does not need a helper or abstraction.
- Do not design for hypothetical future requirements.
- Three similar lines beat a premature abstraction; the **fourth** repetition justifies
  extraction.

## Phase order (foundation first)

Do **not** start with the real AI model. Build in this order:

1. Flutter project structure.
2. Camera screen.
3. Mock detector (`MockToyDetector`).
4. Fake detections (`fake_detections.dart`, `scenario_builders.dart`).
5. Overlay rendering (`DetectionOverlayPainter`).
6. Tracking engine (`ToyTrackingEngine`, `IouCalculator`).
7. Stable counting logic (`ToyCountingService`).
8. Live counter panel (`LiveCounterPanel`).
9. Pause/reset controls.
10. Tests for all of the above.

**Only then** connect TFLite (`TfliteToyDetector` via adapter).

## Why mock-first

The core risk is not only detection accuracy. It is real-time stability, duplicate
prevention, camera performance, UI clarity, and correct business counting. The mock
detector lets all of these be proven and tested deterministically before model variance
is introduced.

## Documentation rule

When a change alters system behavior (a threshold, a layer contract, a category, a
privacy default), update the matching governance file in this folder in the same change.
Governance and code must never drift.
