---
description: Turn an idea into an executable technical specification for ToyVision.
argument-hint: <idea o feature a especificar>
---

Convert this idea into an executable technical spec: $ARGUMENTS

Do NOT write implementation code. Produce a spec that an owning agent can execute:

```
# Spec: <title>

## Problem / user value
## Owning agent(s)        (route via .toyvision/agent-routing.md)
## Scope (in / out)
## Affected layers        (UI / state / services / inference / storage / validation)
## Files to create or modify
## Data & state model
## Detection/performance considerations   (only if it touches camera/frame loop/inference/overlay)
## Privacy considerations
## Acceptance criteria     (testable, numbered)
## Test plan               (unit + scenario + visual evidence if UI)
## Risks & mitigations
## Open questions
```

Keep scope minimal and aligned with the current phase. Flag anything that would expand product scope so the user can decide.
