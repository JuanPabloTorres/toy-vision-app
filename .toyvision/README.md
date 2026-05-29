# ToyVision Real-Time — Governance Folder

This folder is the **single source of truth** for how ToyVision Real-Time is designed,
built, reviewed, and shipped. Any coding agent (Claude, Copilot, Codex, or human)
**must read the relevant files here before writing or modifying code.**

## What is ToyVision Real-Time

A mobile-first, AI-powered application that detects, identifies, tracks, and counts
toys in real time using the device camera. A parent or guardian points the camera at a
play area and sees toys detected live with bounding boxes, labels, a stable count, and a
per-category summary — with pause, reset, and save-summary actions.

The detection loop runs **locally on the device**. The MVP begins with a **mock
detector** before any real model is connected.

## How to use this folder

1. Read [project-operating-system.md](project-operating-system.md) first.
2. Read [agent-routing.md](agent-routing.md) to find the agent that owns your task.
3. Read the owning agent file in [agents/](agents/).
4. Apply the relevant skills in [skills/](skills/).
5. Respect [architecture-principles.md](architecture-principles.md) layer boundaries.
6. Respond using the agent response standard before changing code.

## File index

### Core governance
| File | Purpose |
|------|---------|
| [project-operating-system.md](project-operating-system.md) | Master rules, development cycle, definition of done |
| [technology-stack.md](technology-stack.md) | Approved stack and change process |
| [architecture-principles.md](architecture-principles.md) | Layers and their single responsibilities |
| [design-patterns.md](design-patterns.md) | Required patterns and where to apply them |
| [development-methodology.md](development-methodology.md) | Task cycle and phase order |
| [business-logic-principles.md](business-logic-principles.md) | Validation and counting rules |
| [realtime-detection-flow.md](realtime-detection-flow.md) | End-to-end frame pipeline and performance |
| [ui-ux-guidelines.md](ui-ux-guidelines.md) | Visual direction, screen states, UX safety |
| [reusable-components-guidelines.md](reusable-components-guidelines.md) | Shared components and design tokens |
| [ai-model-guidelines.md](ai-model-guidelines.md) | Model role, output contract, constraints |
| [privacy-safety-guidelines.md](privacy-safety-guidelines.md) | Non-negotiable privacy and safety rules |
| [testing-strategy.md](testing-strategy.md) | Unit, product, and acceptance testing |
| [agent-routing.md](agent-routing.md) | Which agent owns which kind of task |

### Agents
See [agents/](agents/) — one file per role, each with rules and a response format.

### Skills
See [skills/](skills/) — one guardrail per file, applied while working in an area.

## Golden rules (summary)

- ToyVision counts **validated, tracked, stable toys** — never raw detections.
- The model is a **detector**, not the business decision-maker.
- **No people, no faces, no pets, no child identification.**
- **No saving video, no uploading frames** by default.
- **Mock detector first**; real model only after tracking + counting are proven.
- Each layer keeps **one responsibility**; UI renders prepared state only.
