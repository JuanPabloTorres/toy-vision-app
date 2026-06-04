"""Detector strategy interface + concrete implementations.

Phase 5.0.1 swaps in [YoloWorldDetector] (real open-vocabulary detection
via Ultralytics' YOLO-World). The [PlaceholderDetector] is kept so the
server can boot even when the heavy ML deps are not installed yet — and
so unit tests can exercise the wire without downloading weights.

Privacy: no image, frame, or pixel data is read, written, or persisted
by anything in this module. JPEG bytes are decoded in memory and the
buffer is discarded as soon as the model returns boxes.
"""
from __future__ import annotations

import base64
import io
import math
import time
from typing import List, Optional, Protocol

from label_mapping import SUPPORTED_PROMPTS, to_registry_label
from schemas import BoundingBox, Detection


class Detector(Protocol):
    """Common interface every concrete detector implements."""

    @property
    def name(self) -> str: ...

    def detect(
        self,
        *,
        frame_index: int,
        width: int,
        height: int,
        image_jpeg_base64: Optional[str],
        prompts: Optional[List[str]],
    ) -> List[Detection]: ...


class PlaceholderDetector:
    """Deterministic, frame-indexed fake detector.

    Returns three slowly-moving boxes labelled `toy car`, `stuffed
    animal`, and `ball`. Used when the heavy ML stack is unavailable or
    in unit tests.

    No image, frame, or pixel data is read, written, or persisted.
    """

    @property
    def name(self) -> str:
        return "placeholder"

    def detect(
        self,
        *,
        frame_index: int,
        width: int,
        height: int,
        image_jpeg_base64: Optional[str],
        prompts: Optional[List[str]],
    ) -> List[Detection]:
        t = float(frame_index)
        car_x = 0.10 + 0.30 * (0.5 + 0.5 * math.sin(t * 0.12))
        plush_y = 0.20 + 0.18 * (0.5 + 0.5 * math.sin(t * 0.09 + 1.0))
        ball_x = 0.30 + 0.40 * (0.5 + 0.5 * math.cos(t * 0.07))
        return [
            Detection(
                label="toy car",
                mapped_label=to_registry_label("toy car"),
                confidence=0.71,
                box=BoundingBox(x=car_x, y=0.62, width=0.20, height=0.14),
            ),
            Detection(
                label="stuffed animal",
                mapped_label=to_registry_label("stuffed animal"),
                confidence=0.68,
                box=BoundingBox(x=0.60, y=plush_y, width=0.22, height=0.24),
            ),
            Detection(
                label="ball",
                mapped_label=to_registry_label("ball"),
                confidence=0.55,
                box=BoundingBox(x=ball_x, y=0.30, width=0.10, height=0.10),
            ),
        ]


class YoloWorldDetector:
    """Real open-vocabulary detection via Ultralytics' YOLO-World.

    Loads `yolov8s-world.pt` on first use (~140 MB; downloaded by
    Ultralytics into the user cache the first time). Subsequent calls
    reuse the in-memory model.

    Inference flow:
        1. Base64-decode the incoming JPEG.
        2. Load via Pillow → numpy RGB array.
        3. model.set_classes(prompts or SUPPORTED_PROMPTS).
        4. model.predict(array, conf=0.10, verbose=False).
        5. Map each detection's pixel xyxy box to a normalized
           BoundingBox and run the label through `to_registry_label`.

    Confidence is left raw from YOLO-World; the Flutter business layer
    decides what "counts" as a toy.
    """

    def __init__(self, model_weights: str = "yolov8s-world.pt"):
        self._model_weights = model_weights
        # Lazy: importing ultralytics is heavy. Defer until first call.
        self._model = None
        self._last_class_names: Optional[List[str]] = None

    @property
    def name(self) -> str:
        return "yolo-world"

    def _load(self):
        if self._model is not None:
            return self._model
        from ultralytics import YOLO  # heavy import, lazy
        self._model = YOLO(self._model_weights)
        return self._model

    def detect(
        self,
        *,
        frame_index: int,
        width: int,
        height: int,
        image_jpeg_base64: Optional[str],
        prompts: Optional[List[str]],
    ) -> List[Detection]:
        if not image_jpeg_base64:
            # No image bytes → can't run real detection. Return empty so
            # the client sees nothing rather than a stale frame.
            return []

        # Decode image. Discard the raw bytes immediately afterward —
        # the model keeps only the numpy array for the duration of the
        # call.
        from PIL import Image
        import numpy as np

        raw = base64.b64decode(image_jpeg_base64)
        image = Image.open(io.BytesIO(raw)).convert("RGB")
        arr = np.array(image)
        img_h, img_w = arr.shape[:2]

        class_names = prompts or SUPPORTED_PROMPTS
        model = self._load()
        if class_names != self._last_class_names:
            # set_classes recomputes the text-embedding head; only do it
            # when the prompt list actually changes.
            model.set_classes(class_names)
            self._last_class_names = list(class_names)

        results = model.predict(
            arr,
            conf=0.10,
            verbose=False,
            imgsz=640,
        )

        detections: List[Detection] = []
        for r in results:
            boxes = getattr(r, "boxes", None)
            if boxes is None:
                continue
            names_map = r.names  # {int: name}
            for i in range(len(boxes)):
                cls_id = int(boxes.cls[i].item())
                cls_name = names_map.get(cls_id, str(cls_id))
                conf = float(boxes.conf[i].item())
                x1, y1, x2, y2 = (
                    boxes.xyxy[i].cpu().numpy().tolist()
                )
                # Normalize pixel coords to [0, 1].
                nx = max(0.0, min(1.0, x1 / img_w))
                ny = max(0.0, min(1.0, y1 / img_h))
                nw = max(0.0, min(1.0, (x2 - x1) / img_w))
                nh = max(0.0, min(1.0, (y2 - y1) / img_h))
                if nw <= 0 or nh <= 0:
                    continue
                detections.append(
                    Detection(
                        label=cls_name,
                        mapped_label=to_registry_label(cls_name),
                        confidence=conf,
                        box=BoundingBox(x=nx, y=ny, width=nw, height=nh),
                    )
                )
        return detections


def make_detector() -> Detector:
    """Pick the strongest detector that can actually load.

    Tries [YoloWorldDetector] first; if Ultralytics is missing or the
    weights cannot load on import-test, falls back to
    [PlaceholderDetector] so the server still boots and the wire stays
    testable. Logs the choice once on startup.
    """
    try:
        # Probe the import without actually downloading weights yet.
        import importlib

        importlib.import_module("ultralytics")
        det = YoloWorldDetector()
        print("[vision-server] selected detector: yolo-world (lazy load)")
        return det
    except Exception as exc:  # pragma: no cover - boot path
        print(
            "[vision-server] yolo-world unavailable, "
            f"using placeholder ({exc.__class__.__name__}: {exc})"
        )
        return PlaceholderDetector()
