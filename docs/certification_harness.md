# Toy Vision capture, replay and corpus certification

This harness is development instrumentation. Normal builds retain neither
frames nor perception traces. A certification build must opt in to metadata;
retaining pixels requires a second, explicit flag and informed consent for
every person and private space that may appear.

## One-command Galaxy S25 capture

Connect exactly one unlocked Galaxy S25 with USB debugging enabled and accept
the RSA prompt. From the repository root run:

```powershell
adb devices -l
.\tools\certify_galaxy_s25.ps1 -IUnderstandFramesAreStored -UseGpu -MonitorSeconds 900
```

The script validates the model before modifying the device. A non-S25 produces
`BLOCKED_PHYSICAL_DEVICE_WRONG_MODEL` and is not used. A successful run builds
and installs the capture APK, launches the real camera/TFLite path, gathers
logcat, battery, thermal, memory, CPU and frame timing evidence, prompts for the
acceptance scenarios, records manual audio/haptics/Rive/Tobi checks, pulls the
capture, and writes `physical_run.json` plus `performance_summary.json` under
`certification/runs/<UTC stamp>`. Raw CPU, memory, thermal, battery, graphics,
camera service, GPU capabilities and logcat evidence remain beside the summary
so the calculated values are auditable. The ADB serial is used only to address
the device and is stored solely as a truncated SHA-256 fingerprint.

The capture APK is built with:

```text
TOYVISION_CAPTURE=true
TOYVISION_CAPTURE_FRAMES=true
TOYVISION_CAPTURE_SCENARIO=galaxy_s25_certification
TOYVISION_USE_GPU=true
```

Metadata-only captures may omit `TOYVISION_CAPTURE_FRAMES`; no image path or
frame file is then written. Never publish or commit captured pixels. Delete the
device and local copies after the labelled development corpus has served its
approved retention purpose.

## Evidence schema

Every line in `frames.jsonl` has the source timestamp and native detector
latency/FPS; detector proposals, normalized boxes and confidences; crop and
scene embeddings; fusion scores; track IDs and component association scores
(IoU, geometry, size and cosine similarity); scene stability and motion;
occluded IDs; missing/disappearance evidence and decisions; domain events;
session/completion state; stage latency, dropped frames and scheduler state.

When pixels are enabled, `imagePath` points to the exact JPEG byte sequence
given to `PerceptionEngine`. Replay therefore uses the same pixels and recorded
native proposals, not regenerated or mocked detections.

## Human annotation and corpus manifest

Generate, then manually complete, one annotation file per capture:

```powershell
C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart template `
  <capture-directory> <session-id>.annotations.json
```

Set `annotationStatus` to `COMPLETE` only after every recorded frame has:

- `cameraMoving` reviewed;
- stable physical `objectId` values across time;
- `kind` (`toy` for any positive cleanup item or `nonToy` for a negative;
  legacy schema names), visibility, occlusion and normalized bounds;
- expected collection windows and expected session completion reviewed.

Build `certification/dataset.json` from `dataset.example.json`. It must contain
independent `train`, `validation` and `test` sessions and collectively cover:
known and unknown toys, stuffed toys, vehicles, figures, blocks, small objects,
loose clothing, shoes, books, backpacks, remotes, bottles and boxes as positive
cleanup items; partial occlusion, multiple similar items, low light, motion
blur, hands, camera motion and disappear/reappear. Hard negatives must include
the same item types while worn, held or stored, plus people, furniture,
fixtures and empty floor. Paths are resolved relative to the dataset manifest.

## Validate, calibrate and evaluate

```powershell
C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart validate certification/dataset.json

C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart calibrate-embedding `
  certification/dataset.json certification/results/embedding-calibration.json

C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart evaluate `
  certification/dataset.json certification/results/final-test
```

Calibration uses only the train split, checks it on validation and requires at
least two independent training sessions. It writes recommendations but never
changes production thresholds automatically. Final evaluation uses the held-out
test split and reports precision, recall, F1, false positives/negatives,
hard-negative false positives, ID switches, duplicate/false/missed collections,
completion mismatches, embedding identity and toy/non-toy AUC, and latency
p50/p95/p99. Each evaluated session also gets an exhaustive
`replay_trace.jsonl`.

Exit codes are `0` for passed evidence, `1` for a completed evaluation that
fails gates, and `2` for missing/incomplete evidence. A synthetic automated
replay proves harness mechanics only; it cannot certify real-world quality.
