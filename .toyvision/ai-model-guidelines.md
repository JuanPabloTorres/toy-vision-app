# AI Model Guidelines — ToyVision Real-Time

The model is a **detector**, not the business decision-maker. It proposes; the Business
Logic Layer disposes.

## Phase rule

The MVP **must** begin with `MockToyDetector`. Only after the camera, overlay, tracking,
and counting work correctly — and pass tests — may the real model be connected via
`TfliteToyDetector` (wrapped by `TfliteToyDetectorAdapter`).

## Model direction

- YOLO-based detector.
- TensorFlow Lite export.
- Local, on-device inference.
- Start with a small / nano model variant.

## Model output contract

The detector returns raw detections in normalized coordinates:

```json
{
  "label": "toy_car",
  "confidence": 0.91,
  "box": { "x": 0.12, "y": 0.20, "width": 0.30, "height": 0.18 }
}
```

`MockToyDetector` must produce output in this exact shape so it is swap-compatible with
the real detector.

## The model must not

- decide the final count;
- decide user-facing certainty;
- identify people;
- perform face recognition;
- save frames;
- upload frames.

## Class list discipline

- The model's class list and `ToyCategoryRegistry` must stay in sync.
- Changing a label, adding a class, or removing a class requires updating the registry in
  the same change. See [business-logic-principles.md](business-logic-principles.md).
- A label the registry does not know is treated as `unknown` and ignored — never counted.

## Versioning & evaluation

- Every exported model has a version recorded (and, later, a `ModelVersionRepository`).
- Models are evaluated before promotion; accuracy/latency are recorded.
- Model selection and dataset rules are owned by the AI Vision Model Agent.

Guardrail: [skills/preserve-ai-model-discipline.md](skills/preserve-ai-model-discipline.md).
