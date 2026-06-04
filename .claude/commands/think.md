---
description: Deep analysis before touching code — impact, layers, risks, no edits.
argument-hint: <problema o cambio a analizar>
---

You are in **analysis-only mode**. Do NOT edit, create, or delete any code.

Analyze the following before any implementation: $ARGUMENTS

Produce the ToyVision agent response standard (from `.toyvision/agent-routing.md`):

```
Objective:
Relevant agent:        (route via .toyvision/agent-routing.md)
Relevant skills:       (guardrails from .toyvision/skills/)
Files to create or modify:
Architecture impact:
Business logic impact:
UI/UX impact:
Privacy impact:
Performance impact:    (camera / frame loop / inference / overlay — latency, memory, FPS, throttling)
Implementation steps:
Tests required:
Acceptance criteria:
Risks:
```

Rules:
- Respect layer separation: UI / state / services / inference / storage / validation.
- Flag any change that touches camera, frame loop, inference, or overlay as performance-sensitive.
- If the task spans layers, sequence it across owning agents.
- End with a clear recommendation. Do not write code until the user approves.
