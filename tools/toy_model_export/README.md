# Toy detector export tooling

This directory is development tooling and is not distributed as executable
Python code inside the mobile application. It exports the current
YOLOv8s-world model to a local TFLite detector with a fixed 30-class cleanup
vocabulary covering toys plus common loose clothing and household items.

The vocabulary is detector training input. Runtime fusion never uses these
strings to decide whether an observation is a cleanup item.

## Reproducible environment

Use Python 3.12 and the exact versions in `requirements.txt`:

```powershell
cd tools/toy_model_export
py -3.12 -m venv .venv312
.\.venv312\Scripts\python.exe -m pip install --upgrade pip
.\.venv312\Scripts\python.exe -m pip install -r requirements.txt
.\.venv312\Scripts\python.exe export_toy_model.py
```

The checked-in artifact was exported with Ultralytics 8.4.60, task `detect`,
input 480×480, float32, and no built-in NMS. Its provenance is recorded in
`yolov8s-world_saved_model/metadata.yaml` and
`docs/ultralytics_dependency_audit.md`.

Exact checked-in artifact:

```text
assets/models/cleanup_items.tflite
62,764,989 bytes
SHA-256 E30E3A03995A2F7E2FFB929D8BA26736EBBE2D275049A64FB35DF7A5F4657FEE
```

Export may still vary across platforms because upstream conversion tools are
not guaranteed bit-for-bit deterministic. Any replacement artifact requires a
new hash, metadata record, corpus evaluation, and physical-device run.

## License boundary

The Python package, source weights, exported artifact, and Flutter runtime are
Ultralytics-derived and marked AGPL-3.0. They cannot be assumed suitable for a
closed commercial distribution. See `docs/ultralytics_dependency_audit.md`.
