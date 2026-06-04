"""Request/response shapes for the ToyVision local vision server.

The shapes are intentionally a strict subset of what an open-vocabulary
detector (YOLO-World, Grounding DINO, OWLv2) needs at the wire, so the
client does not change when the detector is swapped in Phase 5.0.1.
"""
from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    """Normalized [0, 1] bounding box. The client treats the top-left of the
    image as (0, 0) and uses width/height to size the rectangle."""

    x: float = Field(..., ge=0, le=1)
    y: float = Field(..., ge=0, le=1)
    width: float = Field(..., ge=0, le=1)
    height: float = Field(..., ge=0, le=1)


class Detection(BaseModel):
    """One detected object.

    `label` is the raw detector output (e.g. "toy car" from YOLO-World).
    `mapped_label` is the ToyVision registry label (e.g. "toy_car"). The
    business layer downstream uses `mapped_label` and ignores `label`.
    """

    label: str
    mapped_label: str
    confidence: float = Field(..., ge=0, le=1)
    box: BoundingBox


class DetectRequest(BaseModel):
    """Incoming request from the Flutter app.

    Phase 5.0 placeholder: the client sends only the frame index and the
    expected image dimensions; no image bytes are sent yet. Phase 5.0.1
    populates `image_jpeg_base64` and an optional `prompts` list so a real
    detector (YOLO-World) can run.

    Privacy: the server never persists `image_jpeg_base64`. It is decoded
    in memory only and discarded after inference.
    """

    frame_index: int
    width: int = Field(..., gt=0)
    height: int = Field(..., gt=0)
    image_jpeg_base64: Optional[str] = None
    prompts: Optional[List[str]] = None


class DetectResponse(BaseModel):
    """Server reply. `latency_ms` measures detector-only time (excluding
    decode and JSON serialization) so the client can decide whether the
    pipeline is fast enough."""

    detections: List[Detection]
    model: str
    latency_ms: int = Field(..., ge=0)


class HealthResponse(BaseModel):
    status: str
    model: str
    prompts_supported: List[str]
