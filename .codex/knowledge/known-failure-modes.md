# Known failure modes

| Symptom | Likely boundaries to inspect | Required route |
|---|---|---|
| YOLO marks everything | preprocessing, output axes/score decode, NMS, coordinates, model mismatch | `$toyvision-yolo-tflite-debugging` |
| many non-toys become candidates | proposal objectness, semantic source, persistence/fusion blockers | `$toyvision-toy-candidate-validation` |
| game collects by itself | collection event → disappearance → track → candidate → proposal | `$toyvision-false-collection-investigation` |
| completion happens early | snapshot credibility, collected IDs, unresolved/new/uncertain toys, scene verification | same investigation + completion audit |
| toy reappears under new ID | descriptor, greedy assignment, lifecycle, occlusion, reidentification | `$toyvision-tracking-reidentification` |
| pan/shake looks like removal | anchor update, scene state, region reobservation | `$toyvision-scene-stability` |
| unknown toy never confirms | current open-set path lacks validated semantic toy evidence | candidate validation; do not add keywords |
| child flow feels like a demo/dashboard | action hierarchy, feedback latency, dead ends, debug leakage | `$toyvision-flutter-gameplay-ui` |
| desktop is fast but phone is hot/slow | delegate/CameraX/UI/device thermal behavior | `$toyvision-performance-profiling` |

Do not encode a symptom's example as a universal fix. Preserve the failing
trace, locate the first incorrect state, test a hypothesis, then replay the
failure and neighboring adversarial cases.
