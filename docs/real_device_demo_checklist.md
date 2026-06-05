# Toy Vision real device demo checklist

Use this checklist on a real Android/iOS device before calling a build
demo-ready. Record device model, lighting, detector mode, and pass/fail notes.

## Setup

- Device:
- OS version:
- Build:
- Detector shown in Parents/debug panel:
- Room/light conditions:
- Tester:
- Adult present:

## Per-scenario evidence to record

For every scenario below, record these values from the hidden diagnostics
panel and from the tester's observation:

- Baseline toy count:
- Visible toys:
- Selected target:
- Scene stability status/reason/score:
- Guard decision/reason:
- Mission state:
- Auto-collect allowed or blocked:
- Correct or incorrect outcome:
- Approx FPS / frame interval:
- Perceived latency:
- Problem observed:

## Scenarios

- [ ] 1 large toy visible: scan finds it, target box follows it, mission does not complete until pickup evidence or fallback.
- [ ] 1 small toy visible: target remains understandable and does not flicker into a false pickup.
- [ ] 3 toys visible: scan counts multiple toys and guides one at a time.
- [ ] Grouped toys: target highlight stays on the selected toy and does not jump between nearby toys.
- [ ] Partially hidden toy: app avoids inventing a specific toy name and does not auto-complete from a weak detection.
- [ ] Child moves camera quickly: mission asks to look again; no auto-collect.
- [ ] Child moves camera slowly: scene stability catches gradual drift; no auto-collect.
- [ ] Low light: detector behavior is logged; mission stays conservative.
- [ ] Busy background: non-toys are ignored; raw non-toy detections do not unlock completion.
- [ ] Non-toy object that looks toy-like: app ignores it or treats it as uncertain unless toy evidence is clear.
- [ ] Toy leaves camera but is not picked up: no false collected state.
- [ ] Toy is actually picked up while anchors remain stable: auto-collect happens after sustained evidence.
- [ ] Real complete mission: no visible toys remain, scene is stable, and completion is correct.

## Demo readiness notes

- [ ] Child can understand the next action without adult explanation.
- [ ] Target highlight is visible but never stale.
- [ ] Re-scan messages feel calm and short.
- [ ] Diagnostic panel confirms scene stability and guard decisions during risky moments.
- [ ] No photos, video, or sensitive camera data are persisted.
