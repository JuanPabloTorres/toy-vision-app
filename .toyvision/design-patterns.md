# Design Patterns — ToyVision Real-Time

Use these patterns where appropriate. They exist to keep layers swappable, testable, and
free of duplication. Do not invent parallel mechanisms for the same job.

## Repository Pattern
Use for storage and scan history. Hides the storage engine (SQLite/Hive) behind an
interface.
```text
ScanHistoryRepository
ToyInventoryRepository
ModelVersionRepository
```

## Strategy Pattern
Use for interchangeable detection engines. The app depends on the interface, never a
concrete detector.
```text
ToyDetector          // interface
MockToyDetector      // phase 1
TfliteToyDetector    // later
```

## Registry Pattern
Use for centralized category definitions. **One** registry, no duplicated category maps.
```text
ToyCategoryRegistry
```
Each entry defines: label, display name, whether it counts as a toy, minimum confidence,
ignored status, UI display behavior. See [business-logic-principles.md](business-logic-principles.md).

## Service Pattern
Use for business logic. Pure, testable, no UI or camera access.
```text
ToyCountingService
ToyDetectionRules
FrameProcessingService
```

## State Object Pattern
Use for live detection state. Immutable snapshots the UI renders.
```text
LiveDetectionState
TrackedToyState
ToyCountSummary
```

## Adapter Pattern
Use when wrapping TFLite, ONNX, or future runtimes so the rest of the app stays runtime-
agnostic.
```text
TfliteToyDetectorAdapter
```

## Painter Pattern
Use for drawing bounding boxes via CustomPainter. The painter receives prepared state
only — it computes no business values.
```text
DetectionOverlayPainter
```

## Configuration Object Pattern
Use for thresholds and performance settings. **Do not scatter constants across files.**
```text
RealtimeDetectionConfig
```
Holds: `minimumStableFrames`, `maximumMissingFrames`, `iouMatchThreshold`,
`targetInferenceFps`, overlay opacity, and other tunables.

## Pattern selection guide

| Need | Pattern |
|------|---------|
| Swap detection engine | Strategy |
| Wrap a native AI runtime | Adapter |
| Central category truth | Registry |
| Persist summaries/history | Repository |
| Counting / validation logic | Service |
| Pass live state to UI | State Object |
| Draw overlay | Painter |
| Centralize thresholds | Configuration Object |
