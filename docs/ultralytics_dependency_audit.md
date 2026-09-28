# Ultralytics dependency and replacement audit

Audit date: 2026-09-27

This is an engineering inventory, not legal advice. Commercial distribution
remains blocked until counsel or an applicable Ultralytics Enterprise agreement
confirms the intended use.

## Exact dependency chain

| Boundary | Distributed/used component | Evidence | License status |
|---|---|---|---|
| Training tooling | Python `ultralytics==8.4.60`, TensorFlow 2.19, tf_keras 2.19, ONNX 1.21, ONNX Runtime 1.26 | `tools/toy_model_export/requirements.txt` and export log | Ultralytics code is AGPL-3.0 |
| Source model | `yolov8s-world.pt`, fixed to 30 cleanup-item prompts before export | export script and generated metadata | Ultralytics-derived, metadata says AGPL-3.0 |
| Exported format | float32 TFLite, detect, 480×480, 30 classes, 62,764,989 bytes | `yolov8s-world_saved_model/metadata.yaml` | A standard file format does not change model provenance |
| Exported artifact | `assets/models/cleanup_items.tflite`, SHA-256 `E30E3A03995A2F7E2FFB929D8BA26736EBBE2D275049A64FB35DF7A5F4657FEE` | repository artifact | Treat as AGPL/Enterprise-sensitive |
| Mobile runtime | `ultralytics_yolo` 0.4.3 from pub.dev | `pubspec.lock` and cached package metadata | Package LICENSE is AGPL-3.0 |
| App integration | `YOLOView` owns CameraX/TFLite inference and emits pixels plus boxes | `CleanupScreen` and `YoloStreamingFrameAdapter` | Runtime is included in the APK |

The official plugin describes AGPL-3.0 for open-source collaboration and an
Enterprise license for commercial applications that cannot follow AGPL terms:
https://github.com/ultralytics/yolo-flutter-app#license

Ultralytics' official contribution/licensing FAQ states that projects using its
code or models must follow AGPL open-source requirements, or obtain an
Enterprise license when those requirements cannot be met:
https://docs.ultralytics.com/help/contributing/#license

## Separation already enforced

- `ObjectDetector` is a perception port.
- `NativeProposalObjectDetector` only consumes proposals already attached to a
  `CameraPerceptionFrame`; it has no Ultralytics import.
- `PerceptionEngine`, fusion, tracking, disappearance, world model and cleanup
  domain have no dependency on the Ultralytics package.
- The only package-specific runtime boundary is the presentation camera surface
  plus `YoloStreamingFrameAdapter`.
- Labels emitted by the model are diagnostic and do not participate in numeric
  acceptance or collection decisions.

## Closed-commercial replacement route

1. Select a detector runtime and weights with verified commercial terms.
2. Export a local on-device artifact and record its source, versions, license,
   hash, input shape and quantization.
3. Replace `YOLOView` with a camera/inference surface that emits encoded pixels,
   normalized proposal boxes, confidence and latency.
4. Implement or reuse an `ObjectDetector` adapter for those proposals.
5. Keep `CameraPerceptionFrame` and `PerceptionEngine` unchanged.
6. Run the complete train/validation/test corpus, adverse replays and Galaxy S25
   certification. No threshold or acceptance waiver transfers automatically.
7. Remove `ultralytics_yolo`, the Ultralytics model and their transitive native
   artifacts from the release APK, then verify the merged dependency graph and
   licenses again.

## Current decision

`BLOCKED_COMMERCIAL_LICENSE`: the repository contains both an AGPL-marked
runtime and an AGPL-marked exported model. Interface decoupling makes a runtime
replacement possible without changing the verified perception/domain pipeline,
but no replacement has yet been selected or evaluated.
