# Architecture Principles — ToyVision Real-Time

The architecture separates responsibilities clearly. **Each layer has exactly one
responsibility.** Crossing a boundary is a defect, not a shortcut.

## Layers

```text
Camera Layer
Detection Layer
Tracking Layer
Business Logic Layer
UI Layer
Reusable Component Layer
Storage Layer
AI Model Layer
Testing Layer
```

## Data direction

Data flows **one way** through the live pipeline. Lower layers never reach up into UI;
UI never reaches down into inference or math.

```text
Camera → Detection → Tracking → Business Logic → LiveDetectionState → UI
```

## Layer responsibilities

### Camera Layer (`lib/camera/`)
Owns: camera permissions, preview, lifecycle, frame stream, pause/resume, frame
throttling.
Must not: count toys, decide business rules, draw UI overlays, or save video by default.

### Detection Layer (`lib/detection/`)
Owns: the detector interface, the mock detector, the future TFLite detector, and raw
detection output (`label`, `confidence`, `bounding box`).
Must not: decide final count, decide if something is a valid toy, or update UI.

### Tracking Layer (`lib/tracking/`)
Owns: matching detections across frames, preventing duplicate counts, tracked-object
identity, IoU calculation, missing-frame handling.
Must not: own model inference, own UI rendering, or store permanent history.

### Business Logic Layer (`lib/business/`)
Owns: category validation, confidence validation, ignored-object rules, the stable-count
decision, the toy category registry, and final live detection state.
Must not: read camera frames directly, draw UI, or run model inference.

### UI Layer (`lib/ui/`, `lib/camera/screens/`)
Owns: rendering screens, showing the live camera, showing overlay state, displaying
counts, and showing controls.
Must not: calculate toy count, calculate IoU, decide category validity, or contain model
logic.

### Reusable Component Layer (`lib/ui/components/`)
Owns: shared visual components, consistent spacing, buttons, cards, panels, badges,
overlays, status indicators.
Must not: contain feature-specific business logic.

### Storage Layer (`lib/storage/`)
Owns: saved scan summaries, optional local history, user-controlled deletion.
Must not: save raw video by default, silently upload frames, or train models without
consent.

### AI Model Layer (model/dataset assets + `ai-model-guidelines.md`)
Owns: dataset rules, class list, training, export, evaluation, versioning.
Must not: decide final product behavior, or change labels without updating the business
registry.

### Testing Layer (`lib/testing/`, `test/`)
Owns: fake detections, scenario builders, and the validation suites that gate every
feature.

## Boundary enforcement

- A change that puts logic in the wrong layer must be rejected by the Code Review Agent.
- If two layers seem to need the same code, extract it to `core/` — never duplicate.
- Thresholds and tunables live in **one** config object
  (`RealtimeDetectionConfig`), never inline. See [design-patterns.md](design-patterns.md).

See the matching guardrail: [skills/preserve-architecture-boundaries.md](skills/preserve-architecture-boundaries.md).
