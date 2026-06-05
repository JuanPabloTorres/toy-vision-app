# Real-Device Recall Test — Results

> Goal: the **first real win** — one large toy, good light → detected → marked →
> child picks it up → count +1 → area verified → mission completes on its own.
>
> This file is the evidence log for the recall investigation. The app now
> answers "which gate fails?" by itself via the **Detection Recall Lab**
> (debug overlay) and the structured logs below. **No model change** is part of
> this phase — only diagnosis and pipeline/threshold calibration.

## How to run (exact procedure)

1. **Build & install the debug APK** (custom model picked up automatically if
   `assets/models/toys.tflite` is bundled):
   ```
   flutter run --debug        # or: flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
2. **Confirm which detector is live.** In logcat, find the one-shot line on
   model load:
   ```
   adb logcat -s flutter | findstr "[MODEL]"
   ```
   Record `loaded=`, `custom=`, `fallback=`, `confidenceThreshold=` below.
3. **Enable the Detection Recall Lab.** Start a mission, then tap the camera
   card's diagnostics toggle (debug-only). The overlay shows the live funnel:
   ```
   FUNNEL raw=… → mapped=… → valid=… → visible=… → green=…
   VERDICT <plain-language gate diagnosis>
   ```
4. **Point at ONE large toy** in good light, simple background, ~40–80 cm.
   Hold steady ~5 s. Read the FUNNEL/VERDICT and the per-detection rows
   (`rawLabel:conf -> mappedLabel reject=<reason>`).
5. **A/B the threshold.** In the Lab, tap the `confThr` chips
   (`auto / 0.15 / 0.20 / 0.25 / 0.30`). Each tap rebuilds the detector with
   that native floor. Re-point at the toy and record the funnel for each.
6. **Capture logs** for the run:
   ```
   adb logcat -s flutter > device_recall_run.txt
   ```

## What the verdict means (where recall dies)

| VERDICT | Failing gate | Likely fix |
|---|---|---|
| `YOLO sees nothing` | model/native | lower native `confThr`, more light, closer; if `toys.tflite` absent → COCO can't see it |
| `YOLO sees only non-toy classes — mapper drops all` | mapper | the model emits a label we don't map → add to `toyModelLabels` |
| `Mapper accepts N but rules reject all` | rules | confidence below per-category `minimumConfidence`, or invalid box |
| `validated but tracker not stable` | tracking | warm-up; hold steadier / a few more frames |
| `OK: …` | none | recall fine → problem (if any) is downstream (target/auto-collect) |

---

## RESULTS (fill in on device)

### 1. Is `toys.tflite` actually loading?
- `[MODEL] loaded=` …
- `custom=` …  `fallback=` …
- native `confidenceThreshold=` …

### 2. Real labels observed on device (one large toy)
| rawLabel | confidence | mappedLabel | rejectReason | green box? |
|---|---|---|---|---|
| … | … | … | … | … |

### 3. Confidence observed with the large toy
- min / avg / max: …

### 4. Which gate fails (from VERDICT)
- [ ] model not detecting (raw=0)
- [ ] mapper drops (raw>0, mapped=0)
- [ ] rules drop (mapped>0, valid=0)
- [ ] overlay not painting (valid>0, green=0)
- [ ] target not created
- [ ] none — completes the base case ✅

### 5. Threshold A/B evidence
| confThr | raw | valid | false positives | box stable? | target created? |
|---|---|---|---|---|---|
| auto | | | | | |
| 0.15 | | | | | |
| 0.20 | | | | | |
| 0.25 | | | | | |
| 0.30 | | | | | |

- **Recommended threshold + why:** …

### 6. Recommendation
- [ ] keep current model
- [ ] adjust mapper / rules
- [ ] calibrate threshold (value: …)
- [ ] prepare model v2 (`assets/models/toys_v2.tflite` + `toys_v2_labels.txt`)

### 7. Base-case verdict
- [ ] 1 large toy completes end-to-end ✅
- [ ] fails at: …
