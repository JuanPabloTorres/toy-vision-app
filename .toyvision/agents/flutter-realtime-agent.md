# Flutter Real-Time Agent

Owns the on-device handoff from `YOLOView` to `KidGameController` while keeping
the camera responsive and private.

- Map, validate, track, qualify, and accumulate observations in one direction.
- Keep native overlays disabled in Kid Mode.
- Do not add network, storage, or heavy rendering work per frame.
- Preserve camera lifecycle, GPU settings, and debug-only diagnostics.
- Publish `KidGameState`; do not introduce a second cleanup state owner.
