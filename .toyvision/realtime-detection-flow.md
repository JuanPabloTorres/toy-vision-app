# Real-Time Detection Flow

```text
YOLOView results
→ map supported model labels
→ validate categories/confidence/geometry
→ track physical observations
→ qualify scene stability
→ fuse a temporal observation window
→ RoomSnapshot
→ progress and reward update
→ KidGameState
→ Tobi/energy UI
```

The native detector overlay remains disabled. Normal Kid Mode shows no labels,
confidence, tracker identity, exact object estimate, or detection boxes.

## Performance

- Reuse the plugin camera lifecycle and GPU configuration.
- Do not add blocking work, storage writes, or network calls per frame.
- Build snapshots over configured wall-clock windows.
- Keep diagnostics debug-only and presentation lightweight.

## Failure behavior

Insufficient or unstable evidence keeps observation friendly and retryable.
Model errors produce `KidGamePhase.error`; they never fabricate progress.
