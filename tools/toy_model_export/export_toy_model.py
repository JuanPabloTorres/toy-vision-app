"""Export a YOLO-World detector specialized for toys to TFLite.

Run this ONCE on a PC (no GPU required, just slow on CPU). It:
  1. downloads the open-vocabulary `yolov8s-world` weights (~25 MB),
  2. fixes its vocabulary to the toy PROMPTS below (set_classes),
  3. exports a standard YOLO detection model to TFLite.

The resulting `toys.tflite` has those toy prompts baked in as its class
names. Drop it into the Flutter app at:

    assets/models/toys.tflite

and Toy Vision uses it automatically on the next launch
(YoloModelConfig.resolve()).

The exported class names are detector diagnostics only. Runtime acceptance
must remain label-independent and is performed by numeric evidence fusion.

Usage (Windows PowerShell):
    cd tools/toy_model_export
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    python export_toy_model.py
    # → writes ../../assets/models/toys.tflite

License note: Ultralytics YOLO-World is AGPL-3.0. Fine for a personal
prototype; a closed commercial release needs an Ultralytics Enterprise
license or a permissively-licensed alternative.
"""

from __future__ import annotations

import os
import shutil

# Exact vocabulary embedded in the currently distributed artifact. These
# strings are training/export inputs, never runtime decision rules.
PROMPTS = [
    "teddy bear",
    "stuffed animal",
    "plush toy",
    "doll",
    "toy car",
    "toy truck",
    "fire truck",
    "toy train",
    "helicopter",
    "toy helicopter",
    "toy airplane",
    "toy plane",
    "ball",
    "building blocks",
    "lego",
    "ring stacker",
    "stacking rings",
    "action figure",
    "puzzle",
    "toy",
]

# 480 — the only size that exports within this machine's RAM. 576 and 768
# both OOM during onnx2tf (the converter holds the whole graph in memory).
# The recall win for "naves/helicópteros/rojos" comes from the expanded
# PROMPTS + lower confidence, not from resolution. Must be ÷96 for the
# adaptive pool: 480/32=15 (15/3=5 ✓); 640 fails (20/3); 576/768 are valid
# math-wise but OOM on this machine.
IMG_SIZE = 480

OUTPUT_DIR = os.path.join("..", "..", "assets", "models")
OUTPUT_NAME = "toys.tflite"


def main() -> None:
    from ultralytics import YOLO  # heavy import; here so --help stays fast

    print("[toy-export] loading yolov8s-world (downloads on first run)…")
    model = YOLO("yolov8s-world.pt")

    print(f"[toy-export] fixing vocabulary to {len(PROMPTS)} toy classes…")
    model.set_classes(PROMPTS)

    print("[toy-export] exporting to TFLite (this can take a few minutes)…")
    # `export` returns the path to the produced file/dir.
    exported = model.export(format="tflite", imgsz=IMG_SIZE)
    print(f"[toy-export] raw export at: {exported}")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    dest = os.path.join(OUTPUT_DIR, OUTPUT_NAME)

    src = _find_tflite(exported)
    if src is None:
        raise SystemExit(
            "[toy-export] could not locate the .tflite in the export output; "
            f"check {exported} and copy the .tflite to {dest} manually."
        )
    shutil.copyfile(src, dest)
    print(f"[toy-export] DONE → {dest}")
    print("[toy-export] now run `flutter pub get` and relaunch the app.")


def _find_tflite(exported_path: str) -> str | None:
    """Ultralytics may return a file or a directory; find the .tflite."""
    if exported_path and exported_path.endswith(".tflite") and os.path.isfile(
        exported_path
    ):
        return exported_path
    search_root = (
        exported_path
        if exported_path and os.path.isdir(exported_path)
        else "."
    )
    for root, _dirs, files in os.walk(search_root):
        for f in files:
            if f.endswith(".tflite"):
                return os.path.join(root, f)
    return None


if __name__ == "__main__":
    main()
