# Galaxy S25 release validation

This gate cannot be replaced by compilation or desktop replays. Record model,
OS build, ambient conditions, battery state, and a timestamped capture for each
run.

## Automated entry point

```powershell
adb devices -l
.\tools\certify_galaxy_s25.ps1 -IUnderstandFramesAreStored -UseGpu -MonitorSeconds 900
```

The consent switch is mandatory because this certification run retains camera
frames for exact replay. The script rejects a device outside the Galaxy S25
`SM-S93*` family before building or installing. Capture, annotation and corpus
commands are documented in `docs/certification_harness.md`.

## Required scenarios

- Cold start, camera permission grant/denial/retry, bundled model load.
- One large, one small, low-contrast, partially occluded, and unknown toy.
- Two adjacent visually similar toys and a mixed clutter scene.
- Slow pan, fast pan, rotation, blur, hand/laundry-basket occlusion, and return
  to the original viewpoint.
- Toy disappears during camera movement (must not collect), reappears (same
  identity), then is removed from a stable view (exactly one collection).
- Reintroduce a collected-looking object and verify duplicate protection.
- Complete the room and verify one completion event and one persisted summary.
- Background/resume, repeated sessions, battery below 15%, and thermal serious
  and critical states.
- Tobi glTF animations, Rive/Lottie rewards, haptics, music/effects, mute, and
  fallback rendering.

## Measurements

Capture native YOLO latency/FPS, end-to-end frame p50/p95, drop rate, peak RSS,
battery delta over 15 minutes, thermal-state transitions, disappearance
confirmation latency, track ID switches, false collections, double counts,
open-set recall, and completion precision.

## Acceptance record

| Evidence | Result |
|---|---|
| Galaxy S25 connected | `BLOCKED_PHYSICAL_DEVICE_WRONG_MODEL`: ADB exposes SM-S942U (`m1q`, Galaxy S26/API 37), not an SM-S93* S25 |
| Alternate-device smoke/camera/model | PASS on SM-S942U; this does not satisfy the S25 gate |
| Pan/scene-anchor safety | PASS on final instrumented SM-S942U run: 308 frames, 0 collections while viewpoint diverged from anchor |
| Physical detector recall | FAIL in observed scene: snapshot 2 with at least 3 visible toys |
| Full physical cleanup/completion | PENDING; no accepted stable-view removal through celebration |
| Scenario corpus recorded | PENDING |
| Perception accuracy thresholds calibrated | PENDING |
| Sustained thermal/battery limits accepted | PENDING |
| 3D/Rive/Lottie/audio verified on device | PARTIAL: invalid generic Rive HUD found and disabled; remaining channels pending |
| Commercial detector license resolved | PENDING |
