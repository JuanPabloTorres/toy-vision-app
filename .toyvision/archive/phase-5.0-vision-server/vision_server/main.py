"""ToyVision local vision server — FastAPI entry point.

Run with:

    python -m uvicorn main:app --host 0.0.0.0 --port 8000

Endpoints:
    GET  /health   → liveness + selected detector + supported prompts
    POST /detect   → run the detector on one frame

Phase 5.0 wire-up uses the [PlaceholderDetector] so the Flutter integration
can be proven end to end without a heavy ML stack. The real open-vocabulary
detector (YOLO-World) lands in Phase 5.0.1 — only this file changes (the
`detector` global gets swapped).

Privacy: this server never writes to disk. Image bytes passed in (Phase
5.0.1) are decoded in memory only. CORS is permissive because the client
is on the same LAN — never run this server on a public network without
adding auth and an allowlist.
"""
from __future__ import annotations

import time

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from detector import make_detector
from label_mapping import SUPPORTED_PROMPTS
from schemas import DetectRequest, DetectResponse, HealthResponse


app = FastAPI(title="ToyVision Local Vision Server", version="0.2.0")

# CORS: the Flutter app runs on the LAN. Restrict if you ever expose this
# beyond localhost (you should not — this is a dev MVP server only).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Phase 5.0.1: prefer real YOLO-World when ultralytics is installed; fall
# back to placeholder if the import or weight load fails. The choice is
# made once at startup and logged.
detector = make_detector()


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    """Liveness probe + handshake. The Flutter client hits this on startup
    to confirm the server URL is correct and to log the active detector."""
    return HealthResponse(
        status="ok",
        model=detector.name,
        prompts_supported=SUPPORTED_PROMPTS,
    )


@app.post("/detect", response_model=DetectResponse)
def detect(req: DetectRequest) -> DetectResponse:
    """Run the active detector on one frame.

    The request body is small in Phase 5.0 (no image bytes yet); in Phase
    5.0.1 the client populates `image_jpeg_base64` and the detector reads
    that buffer. Either way, no image data is persisted by this handler.
    """
    started = time.perf_counter()
    detections = detector.detect(
        frame_index=req.frame_index,
        width=req.width,
        height=req.height,
        image_jpeg_base64=req.image_jpeg_base64,
        prompts=req.prompts,
    )
    latency_ms = int((time.perf_counter() - started) * 1000)
    return DetectResponse(
        detections=detections,
        model=detector.name,
        latency_ms=latency_ms,
    )
