# Toy model export — YOLO-World → TFLite

This produces `assets/models/toys.tflite`, a detector with a **toy
vocabulary** (dolls, blocks, ring-stackers, plush, toy vehicles…) instead
of the generic COCO-80 classes that `yolo26n` ships with. Once the file is
in place, Toy Vision loads it automatically — no code change.

## Why

`yolo26n` (the default) only knows COCO-80, which has almost no toys
(`teddy bear`, `sports ball` and that's about it). YOLO-World is
**open-vocabulary**: you give it text prompts and it detects those. We
bake a fixed toy prompt list into the export so the phone runs a normal,
fast TFLite detector — no prompts at runtime, fully offline.

## Run it once (Windows PowerShell)

> **Toolchain matters.** The TFLite export path (`onnx2tf`) does **not** work
> on Python 3.13 (only TF 2.21 has 3.13 wheels, which onnx2tf can't use). Use
> **Python 3.12 + TensorFlow 2.19 + tf_keras** — the known-good combo:

```powershell
cd tools/toy_model_export
py -3.12 -m venv .venv312
.\.venv312\Scripts\python.exe -m pip install --upgrade pip
.\.venv312\Scripts\python.exe -m pip install "ultralytics>=8.3.0" "tensorflow==2.19.0" "tf_keras==2.19.0" onnx onnxruntime
.\.venv312\Scripts\python.exe export_toy_model.py
```

(`ultralytics` auto-installs `onnx2tf` / `onnxslim` / `CLIP` during export.)

The script writes `../../assets/models/toys.tflite` (~60 MB). Then back in
the repo root:

```powershell
flutter pub get
flutter run        # the Parent panel will show "Tipo: Modelo de juguetes"
```

## How the app picks it up

`YoloModelConfig.resolve()` probes the asset bundle for
`assets/models/toys.tflite`. If present → uses it (confidence 0.30). If
absent → falls back to `yolo26n`. The Mission screen awaits this before
mounting the camera; the Parent panel shows which model is live.

## Keeping labels in sync

The export's `PROMPTS` list (in `export_toy_model.py`) **must match** the
keys in `lib/detection/yolo/yolo_detection_mapper.dart` →
`toyModelLabels`. Those prompt strings become the model's class names; the
mapper translates them to the app's registry labels. If you add a prompt,
add the matching mapper entry (and a registry category if it's new).

## Tuning

- `IMG_SIZE` is **480** (required — see note below). 640 fails to export
  (YOLO-World's `adaptive_max_pool2d(→3)` needs a feature map divisible by 3;
  480→15×15 works, 640→20×20 fails in ONNX).
- Edit `PROMPTS` to match the toys in your home. More specific prompts
  ("wooden blocks", "rubber duck") often detect better than generic ones.
- If detection is weak, lower `confidenceThreshold` in
  `YoloModelConfig.resolve()` further (already 0.30).

## License

YOLO-World / Ultralytics is **AGPL-3.0**. OK for a personal prototype.
A closed commercial release needs an Ultralytics Enterprise license or a
permissively-licensed detector.
