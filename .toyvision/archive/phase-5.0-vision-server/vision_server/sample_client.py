"""Local smoke-test client.

Uses only `requests` (already pulled in transitively by uvicorn). Run
against a server already started on http://localhost:8000:

    python sample_client.py path/to/test.jpg

Prints the JSON response so you can verify YOLO-World is actually
detecting objects without involving the Flutter app yet.

Privacy: this script never writes the input image anywhere; it only
base64-encodes and sends it to the local server.
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
import time

import urllib.request


def main() -> int:
    p = argparse.ArgumentParser(description="ToyVision sample client.")
    p.add_argument("image", help="Path to a local JPEG/PNG image.")
    p.add_argument(
        "--url",
        default="http://localhost:8000",
        help="Base URL of the local vision server (default: localhost).",
    )
    args = p.parse_args()

    # /health first to confirm we are talking to the right server.
    try:
        with urllib.request.urlopen(f"{args.url}/health", timeout=5) as r:
            health = json.loads(r.read().decode())
    except Exception as exc:
        print(f"FAIL: /health unreachable at {args.url} ({exc})")
        return 2
    print("/health:", json.dumps(health, indent=2))

    # Load and encode the image.
    with open(args.image, "rb") as f:
        raw = f.read()
    b64 = base64.b64encode(raw).decode()
    # Quick width/height guess for the request shape — server doesn't
    # actually need these to be accurate for YOLO-World, but they fill
    # required fields.
    body = json.dumps(
        {
            "frame_index": 0,
            "width": 1280,
            "height": 720,
            "image_jpeg_base64": b64,
        }
    ).encode()

    req = urllib.request.Request(
        f"{args.url}/detect",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            resp = json.loads(r.read().decode())
    except Exception as exc:
        print(f"FAIL: /detect failed ({exc})")
        return 3
    wall_ms = int((time.perf_counter() - t0) * 1000)

    print(
        f"\n/detect | wall={wall_ms} ms | "
        f"model={resp['model']} | "
        f"server_latency={resp['latency_ms']} ms | "
        f"detections={len(resp['detections'])}"
    )
    for i, d in enumerate(resp["detections"]):
        b = d["box"]
        print(
            f"  [{i}] {d['label']!r:20} -> {d['mapped_label']:18} "
            f"conf={d['confidence']:.2f}  "
            f"box=[x={b['x']:.2f},y={b['y']:.2f},"
            f"w={b['width']:.2f},h={b['height']:.2f}]"
        )
    return 0 if resp["detections"] else 1


if __name__ == "__main__":
    sys.exit(main())
