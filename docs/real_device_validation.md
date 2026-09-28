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
- Confirm IMU instrumentation reports gyro/acceleration/orientation and that a
  fast 70° rotation leaves the target `temporarilyLost`.
- Verify a real pickup exposes stable background in the prior ROI and advances
  automatically to the next target without a blocking review screen.
- After the last pickup, sweep left, center, right and floor; confirm guidance
  advances sector by sector while YOLO remains active.
- During final coverage, introduce a new stable toy; confirmation must cancel,
  return to cleaning and select the new target.
- Finish a genuinely empty-room sweep; require exactly one
  `RoomCleanConfirmed`, persisted progress and celebration.
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
Also retain IMU availability, gyro/linear-acceleration peaks, directional
coverage sectors, background-reveal score, optional depth score and every
`cleanDecision` transition.

## Acceptance record

| Evidence | Result |
|---|---|
| Galaxy S25 connected | `BLOCKED_PHYSICAL_DEVICE_WRONG_MODEL`: ADB exposes SM-S942U (`m1q`, Galaxy S26/API 37), not an SM-S93* S25 |
| Alternate-device smoke/camera/model | PASS on SM-S942U; this does not satisfy the S25 gate |
| 2.4.2 integrated camera/model smoke | PASS on profile SM-S942U before the final presentation-only guard and 2.4.3 voice integration: 57 metadata-only frames / 16.09 s, 0 collections and 0 completions; no controlled pickup was executed |
| 2.4.4 diagnostic reproduction | PASS_DIAGNOSTIC on SM-S942U: 438 metadata-only frames / 109.60 s; the mission inventory grew from 3 to 5 during the pan, with 7 missing tracks, 0 collections and 0 completions. This candidate preceded the final inventory-admission fix |
| Final 2.4.4 artifacts | PASS_BUILD: profile SHA-256 `46C24B1C2911109280E511F93ADEA6190BC52C06803AC1E5CE6409C0B08FEB79`; release SHA-256 `DD77393F6F65E484BE69C1CCBCA42E4A1EE8A27E835755C7B1C7F8E566390F94`; both report 2.4.4 (11) |
| Final 2.4.4 profile installation/camera | NOT_EXECUTED: the exact final implementation has not yet been exercised on camera |
| Diagnostic overlay | PASS on the 2.4.1 pre-integration profile; Kid Mode precedence is covered in the 2.4.4 code and final release binary inspection must exclude both diagnostic strings |
| Pan/scene-anchor safety | PARTIAL: no false collection occurred, but the pre-fix 2.4.4 trace reproduced inventory inflation during pan; automated regression covers the final correction, physical confirmation remains pending |
| Physical detector recall | FAIL in observed scene: snapshot 2 with at least 3 visible toys |
| Full physical cleanup/completion | PENDING; no accepted stable-view removal through celebration |
| Scenario corpus recorded | PENDING |
| Perception accuracy thresholds calibrated | PENDING |
| Sustained thermal/battery limits accepted | PENDING |
| Preliminary profile performance | PARTIAL: long 2.4.1 run native p95 164.06 ms, FPS p50 3.99, 719605 KB PSS; 2.4.2 smoke p95 165.21 ms, FPS p50 3.96, thermal status 2 / skin 42.0 °C; recorder overhead present and 2.4.4 not measured |
| 3D/Rive/Lottie/audio verified on device | PARTIAL: invalid generic Rive HUD found and disabled; remaining channels pending |
| Commercial detector license resolved | PENDING |
