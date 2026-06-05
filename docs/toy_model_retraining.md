# Retraining `toys.tflite` for reliable toy detection

> Status: **plan / recipe**. The current `assets/models/toys.tflite` is a
> YOLO-World–style export with **inconsistent toy recall** (weak on red/saturated
> objects, flickers between `toy` and COCO classes, low confidence). The mission
> *logic* is robust, but precision is capped by the model. This is the path to
> raise precision. **No model change ships without the owner's go-ahead and an
> evaluation table.**

## Why retrain (evidence from device audit, 2026-06-04)
- Live `[RAW]` logs show toys emitted as `toy / toy car / toy truck` **and** as
  COCO classes (`car`, `truck`, `fire hydrant` for red toys) inconsistently.
- Red/saturated toys (a red ball, a red truck) are detected at low confidence or
  mislabeled `fire hydrant`/`sports ball` → dropped or rejected.
- Reframing to a desk makes recall collapse (sees `keyboard/tv`, `raw=0` on toys).
- Runtime mitigations already applied: per-category thresholds lowered to 0.30,
  `fire hydrant → object` mapping, GPU/lifecycle camera fixes. These help but the
  ceiling is the model.

## Dataset (owner action)
Capture **the actual toys** that will be used in demos, in the actual room/light.
1. 150–300 photos per toy class, varied: angle, distance (0.3–2 m), lighting
   (window + lamp), background (floor, rug, table), partial occlusion, grouped
   with other toys, and **on the floor as a child would leave them**.
2. Include the hard cases explicitly: **red/saturated toys**, shiny/plush, small
   blocks, and toys lying flat.
3. Label with a tight box per toy. Keep a small, stable class set, e.g.:
   `toy_car, toy_truck, ball, stuffed_animal, doll, blocks, figure, object`
   (must match the labels in [toy_category_registry.dart](../lib/business/toy_category_registry.dart)).
4. Split 80/10/10 train/val/test. Keep the **test set** untouched for evaluation.

## Export recipe (known-good toolchain)
The export is finicky — use this exact stack (validated previously):
- **Python 3.12**, **TensorFlow 2.19**, **`tf_keras`** installed.
- Ultralytics YOLO (v8/v11 detect). Train, then export with **`imgsz=480`**
  (the plugin runs 480; mismatched imgsz silently degrades recall).
- Export: `yolo export model=best.pt format=tflite imgsz=480 int8=False`
  (try `int8=True` only with a representative calibration set; verify recall).
- Output → `assets/models/toys.tflite` (the app's `YoloModelConfig.resolve()`
  picks it up automatically). See `tools/toy_model_export/`.

## Evaluation gate (required before shipping a new model)
Run on the held-out **test set** and record a table:
| class | precision | recall | mAP@0.5 | notes (red? small?) |
Ship only if recall on the demo toys (esp. **red**) clears a sane bar (e.g. ≥0.85
@ conf 0.25) AND on-device `[RAW]` shows stable `toy*` labels (not COCO flicker).
Attach before/after `flutter analyze`, `flutter test`, and device `[RAW]`/`[MAP]`
logs. Version the dataset + model + export per the repo's AI-change rule.

## Runtime knobs (already in code, tune with the new model)
- `YoloModelConfig`: `confidenceThreshold` (0.25 custom), `iouThreshold`,
  `cameraResolution` (720p), `useGpu`.
- [toy_category_registry.dart](../lib/business/toy_category_registry.dart):
  per-class `minimumConfidence` (currently 0.30) — raise once recall improves.
- [yolo_detection_mapper.dart](../lib/detection/yolo/yolo_detection_mapper.dart):
  label → toy-category mapping (incl. the `fire hydrant → object` red-toy proxy).
