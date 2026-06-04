# AI Model Guidelines — ToyVision Real-Time

The detector is **a proposer**, not the business decision-maker. It emits raw observations;
the Business Logic Layer (`ToyDetectionRules`, `ToyTrackingEngine`, `ToyCountingService`,
and the manual `CandidateReviewService`) decides what those observations mean.

## Detector modes (Phase 5.0)

Three detectors are wired behind the `ToyDetector` interface and selected at runtime via
`ToyDetectorMode`:

| Mode | Primary | Fallback | When to use |
|------|---------|----------|-------------|
| `mock` | `MockToyDetector` | — | Demo, development, deterministic tests |
| `mlkitWithFallback` | `MlKitObjectDetector` (Google ML Kit, on-device) | `MockToyDetector` | Default for users; offline; coarse 5-class output is treated as an "Object Assist" hint that the user confirms via the manual review panel |
| `remoteVisionServer` | `RemoteVisionDetector` (HTTP client → local Python server in `tools/vision_server/`) | `MockToyDetector` | Open-vocabulary detection on the user's own PC over the LAN; never a third party |

The mode toggle cycles `mock → mlkitWithFallback → remoteVisionServer → mock`. Every
non-mock primary is wrapped in `FallbackToyDetector` so a failed initialize or runtime
error degrades to the mock detector instead of crashing the live loop.

## Phase rule

Phase 1 began with `MockToyDetector`. Phase 5.0 adds ML Kit and the remote vision server,
but **the mock detector is still the contract reference** — any new detector must produce
output in the same `RawDetection` shape so it is swap-compatible.

## Model output contract

Every detector returns raw detections in normalized image coordinates:

```json
{
  "label": "toy_car",
  "confidence": 0.91,
  "box": { "x": 0.12, "y": 0.20, "width": 0.30, "height": 0.18 }
}
```

- `label` is mapped through `ToyCategoryRegistry`. ML Kit's 5-class output is bridged by
  `MlKitLabelMap`; remote-server labels are bridged by the server's own label mapping
  (`tools/vision_server/label_mapping.py`).
- A label the registry does not know is treated as `unknown` and ignored — never counted.

## The detector must not

- decide the final count;
- decide user-facing certainty;
- identify people;
- perform face recognition;
- save frames to disk;
- upload frames anywhere other than the user's own local vision server (and only when the
  user has explicitly enabled `remoteVisionServer` mode).

## Remote vision server contract

The remote detector is an HTTP client; the server is the user's own machine on the LAN.

- **Transport:** `http` package; JSON request/response.
- **Schemas:** `lib/detection/detectors/remote/remote_vision_schemas.dart` is a 1:1 mirror
  of `tools/vision_server/schemas.py`. Wire-shape changes require updating both files
  in the same change.
- **Frame encoding:** `CameraImageJpegEncoder` converts YUV420 (Android) / BGRA8888 (iOS)
  to a downscaled JPEG (`targetMaxSide ≈ 480`, `jpegQuality ≈ 60`) before POSTing.
- **Privacy:** frames are sent only to the user-configured `baseUrl`. There is no cloud
  endpoint, no analytics, no third-party network call. The server is operated by the user.
- **Failure policy:** any HTTP/network/timeout error in `RemoteVisionDetector` → frame
  dropped (non-fatal); if `initialize` fails, `FallbackToyDetector` switches to mock.

## ML Kit (Object Assist) contract

- **Plugin:** `google_mlkit_object_detection` (on-device, no network).
- **Output:** ML Kit emits a small, generic class set ("Home good", "Fashion good",
  "Food", "Place", "Plant"). `MlKitLabelMap` translates these into registry labels.
- **Intended UX:** treated as an *assist*. The user confirms / rejects each candidate via
  the review panel before it is counted. The "Object Assist" banner explains this in the
  live screen.
- **Failure policy:** plugin not available, init error, or per-frame error → drop frame
  and let `FallbackToyDetector` use the mock detector.

## Class list discipline

- The detector's effective class list and `ToyCategoryRegistry` must stay in sync.
- Changing a label, adding a category, or removing a category requires updating the
  registry (and any detector-side label maps) in the same change.
  See [business-logic-principles.md](business-logic-principles.md).

## Out of scope (deprecated)

The following paths were explored in earlier phases and have been **archived**, not
pursued:

- Custom dataset capture and training (EfficientDet via MediaPipe Model Maker, Colab).
- Bundled `tflite_flutter` runtime and `assets/models/*.tflite`.
- COCO SSD as a production baseline.

All deprecated docs live in [archive/model-training/](archive/model-training/). Class
taxonomy and privacy rules from that era survive as living reference docs in
[reference/](reference/).

Guardrail: [skills/preserve-ai-model-discipline.md](skills/preserve-ai-model-discipline.md).
