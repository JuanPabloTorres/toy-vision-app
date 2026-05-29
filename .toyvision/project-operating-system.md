# Project Operating System — ToyVision Real-Time

This document governs all development. It overrides convenience, speed, and personal
preference. If a request conflicts with these rules, stop and surface the conflict.

## Main product goal

Let a parent or guardian open the camera, point it at a play area, and see toys detected
in real time with:

- live bounding boxes;
- toy labels;
- a stable toy count;
- count by category;
- ignored non-toy objects;
- pause, reset, and save-summary actions.

## Core principle

ToyVision does **not** count raw AI detections. A toy is counted only after passing,
in order:

1. category validation;
2. confidence validation;
3. bounding box validation;
4. real-time tracking validation;
5. stability validation across frames;
6. duplicate prevention;
7. privacy and safety rules.

## Non-negotiable rules

- Do not identify children, people, or perform face recognition.
- Do not save video by default. Do not upload camera frames by default.
- Do not count the same toy repeatedly across frames.
- Do not put counting logic inside UI widgets.
- Do not let the AI model decide final business results.
- Do not depend on backend calls for every video frame.
- Do not scatter thresholds across random files.
- Do not treat unknown objects as toys.
- Do not skip the mock-detector phase.

## Required implementation order

1. Create project instruction files (this folder).
2. Define agents and skills.
3. Define architecture principles.
4. Define technology decision process.
5. Define UI/UX principles.
6. Define business logic principles.
7. Define AI model principles.
8. Define privacy and safety rules.
9. Only then begin code implementation.
10. Start implementation with mock detection before real model integration.

## Development cycle (every task)

1. Understand the product rule.
2. Identify the responsible agent ([agent-routing.md](agent-routing.md)).
3. Apply the relevant skills ([skills/](skills/)).
4. Propose a minimal plan.
5. Implement only the necessary layer.
6. Add or update tests.
7. Validate architecture boundaries.
8. Document decisions.

## Definition of done

A feature is **not** done unless it:

- follows architecture boundaries;
- respects privacy rules;
- avoids duplicate counting;
- works with mock state;
- has testable logic;
- introduces no unnecessary dependencies;
- keeps UI consistent;
- is documented when it changes system behavior.

## Forbidden implementation patterns

- Building everything in one screen file.
- Placing AI inference inside UI widgets.
- Placing business rules inside painters or components.
- Processing every camera frame without throttling.
- Counting objects directly from model output.
- Saving raw video by default; uploading frames continuously.
- Treating unknown objects as toys.
- Creating duplicated category maps.
- Hardcoding thresholds in multiple files.
- Connecting the real model before tracking/counting is proven.

## First approved development target

The first coding phase creates: Flutter project structure, camera screen, mock detector,
raw detection model, bounding box model, detection overlay, tracking engine, stable
counting service, live counter panel, and pause/reset controls. The real model comes
after this foundation works. See [development-methodology.md](development-methodology.md).
