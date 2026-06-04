# ToyVision Local Vision Server

Phase 5.0 wire-up of the Python local detection server. The Flutter app
on the Galaxy S25 (and any other LAN device on the same Wi-Fi) talks to
this server over plain HTTP to get bounding boxes for the live camera
frames.

> **Status: Phase 5.0 — placeholder detector.**
> The server currently returns deterministic, frame-indexed fake boxes
> (`toy car`, `stuffed animal`, `ball`) so the end-to-end Flutter wiring
> can be proven before installing heavy ML dependencies. Phase 5.0.1
> swaps in YOLO-World (open-vocabulary, real detection) once the wire is
> confirmed working on the S25.

## Why a local server

ToyVision needs an **open-vocabulary** detector that can find objects by
text prompt (`toy car`, `stuffed animal`, `ball`, …) instead of the
fixed COCO 80-class list. The Python ML ecosystem has working open-
vocabulary detectors today (YOLO-World, Grounding DINO, OWLv2); the
Dart/Flutter ecosystem does not. Running the detector on the developer's
PC over the LAN is the smallest viable architecture: no cloud, no
training, no on-device model integration headaches.

## Architecture

```text
Galaxy S25 (Flutter)         your PC (Python)
─────────────────────────    ──────────────────────────────
Camera preview           ───► POST /detect  ──► YOLO-World*
                                                   │
Overlay + review panel  ◄───  JSON {boxes} ◄──── PlaceholderDetector  ← Phase 5.0
Local history saved                              YOLO-World            ← Phase 5.0.1
```

`*` real detector lands in Phase 5.0.1. For now `PlaceholderDetector`
runs.

## Privacy

- **No image, frame, or pixel data is persisted** by this server.
- Phase 5.0 (now): the client does not even send image bytes — only the
  frame index and dimensions. The placeholder ignores them.
- Phase 5.0.1: the client will send a single JPEG per request. The
  detector decodes it in memory, runs inference, and discards the buffer
  before responding. No disk write.
- This server is intended for **local network only**. CORS is permissive
  because the client is on the same LAN. Do not expose it to the public
  internet without adding auth and a HOST allowlist.

## Run

```powershell
# from this folder
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

`--host 0.0.0.0` is required so the phone on the LAN can reach the
server. Listening only on `127.0.0.1` would block the S25.

## Find your PC IP (so the Flutter client can reach you)

On Windows PowerShell:

```powershell
Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp `
  | Select-Object -ExpandProperty IPAddress
```

Pick the LAN IP (typically `192.168.1.x` or `10.x.x.x`). Phone + PC must
be on the same Wi-Fi.

Then in the Flutter app, edit
[`lib/detection/detectors/remote/remote_vision_config.dart`](../../lib/detection/detectors/remote/remote_vision_config.dart)
and set `kRemoteVisionServerUrl` to `http://<your-pc-ip>:8000`.

## Endpoints

### `GET /health`

```json
{
  "status": "ok",
  "model": "placeholder",
  "prompts_supported": [
    "toy", "toy car", "toy truck", "ball", "stuffed animal", "doll",
    "building blocks", "action figure", "toy train", "puzzle",
    "board game", "book", "person", "pet"
  ]
}
```

### `POST /detect`

Request:

```json
{
  "frame_index": 42,
  "width": 1280,
  "height": 720,
  "image_jpeg_base64": null,
  "prompts": null
}
```

`image_jpeg_base64` and `prompts` are optional in Phase 5.0; the
placeholder ignores them. The Flutter client populates them in Phase
5.0.1.

Response:

```json
{
  "detections": [
    {
      "label": "toy car",
      "mapped_label": "toy_car",
      "confidence": 0.71,
      "box": { "x": 0.18, "y": 0.62, "width": 0.20, "height": 0.14 }
    },
    {
      "label": "stuffed animal",
      "mapped_label": "stuffed_animal",
      "confidence": 0.68,
      "box": { "x": 0.60, "y": 0.27, "width": 0.22, "height": 0.24 }
    },
    {
      "label": "ball",
      "mapped_label": "ball",
      "confidence": 0.55,
      "box": { "x": 0.40, "y": 0.30, "width": 0.10, "height": 0.10 }
    }
  ],
  "model": "placeholder",
  "latency_ms": 0
}
```

`mapped_label` is the field the Flutter business layer consumes. `label`
is the raw open-vocabulary string (kept for diagnostics + screenshots).

## Tests

```powershell
pip install pytest httpx
pytest test_main.py
```

Five tests cover: `/health`, three-box response shape, normalized box
coordinates, frame-indexed determinism, and minimal request shape (no
image bytes needed in Phase 5.0).

## Next phase

**Phase 5.0.1 — Swap in YOLO-World.** Replace
`detector = PlaceholderDetector()` in `main.py` with a YOLO-World
adapter that reads the JPEG bytes from `image_jpeg_base64`, runs
inference with the prompts list, and returns the same `Detection` shape.
The Flutter client does not change.

## What this server is NOT

- Not a cloud service.
- Not a training pipeline.
- Not a dataset tool.
- Not a production server (no auth, no rate-limiting, no TLS).
- Not a substitute for a custom on-device model — that is the long-term
  product direction. This server is the **bridge** that makes ToyVision
  useful while the long-term direction is built.
