# Preserve Real-Time Performance

When editing camera or observation flow:

- avoid allocation-heavy transforms and UI work per result callback;
- never add network or storage writes per frame;
- reuse one tracker, scene-quality service, and snapshot builder per session;
- build snapshots on configured wall-clock windows;
- keep native overlays disabled and diagnostics debug-only;
- preserve camera lifecycle cleanup and GPU configuration;
- validate responsiveness on the physical device after automated gates.
