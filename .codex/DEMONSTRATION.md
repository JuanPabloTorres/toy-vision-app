# Workflow demonstration

These are routing simulations, not claims that a new physical failure was
reproduced. Each starts from the evidence the selected skill requires.

## “YOLO está marcando todo”

- Orchestrator selects read-only `yolo_debugger` first; `perception_engineer`
  owns a later implementation only after the faulty boundary is known.
- Execute `$toyvision-yolo-tflite-debugging`.
- Required evidence: model/hash/metadata, exact frame, orientation/resize and
  tensor input contract, raw output distribution when accessible, one manually
  decoded proposal, NMS, adapter normalization, and preview coordinates.
- The first action is not to raise 0.25. If raw tensors are unavailable through
  the plugin, report that stage `BLOCKED` and do not invent it.
- Gates: adapter/coordinate tests, hard-negative and positive corpus, full
  replay, zero false collection, static gate, and physical-device TFLite run.

## “Toy Vision está recogiendo solo”

- Orchestrator selects `adversarial_qa` to preserve the reproduction, then
  `false_collection_specialist`; ownership is handed to perception or tracking
  only after the first wrong fact is established.
- Execute `$toyvision-false-collection-investigation`.
- Required evidence: exact `ToyCollected` timestamp/track, initial snapshot,
  cleanup acceptance, complete disappearance blockers, track/association and
  interaction history, candidate/detection/proposal trace, and consented frame
  evidence where necessary.
- Reverse chain: event → evidence → track → observation → candidate → decoded
  proposal → raw/preprocessing. Missing/pan/occlusion/lost track is not pickup.
- Gates: original replay; pan, shake, cover, low light, person/hand occlusion,
  reappearance, same toy twice, multiple toys, empty scene; zero false/duplicate
  collection and no premature completion; independent release verdict.

## “El gameplay no se siente como un juego”

- Orchestrator selects `gameplay_engineer` for loop/pacing and
  `flutter_ui_engineer` for implementation; `test_engineer` validates the flow.
- Execute `$toyvision-flutter-gameplay-ui`.
- Required evidence: screen/action/state map from Home through Celebration,
  domain-event-to-feedback latency, child-facing copy/HUD/Tobi/progress,
  dead-end/error paths, small screen/text scale, reduced motion, and rebuild
  behavior. No detector scores are accepted as gameplay feedback.
- Gates: widget/feedback tests, full observable child loop, debug separation,
  accessibility/responsive checks, animation/audio fallbacks, performance if
  per-frame UI changes, and device checks for camera/haptics/3D/audio claims.

In all three cases the implementation agent may report technical completion,
but only `release_auditor` may issue the independent final readiness verdict.
