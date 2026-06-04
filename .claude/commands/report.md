---
description: Generate a findings / changes / risks report for recent work.
argument-hint: [alcance: diff | módulo | sesión]
---

Produce a structured report for: ${ARGUMENTS:-current working changes}

Use git status/diff and codegraph impact to gather facts. Do NOT modify code.

```
# Report — <scope> — <date>

## Summary
## Changes made            (file:line, grouped by layer)
## Findings                (what was discovered, severity)
## Risks                   (real risks, with likelihood/impact)
## Performance notes        (camera/frame loop/inference/overlay if touched)
## Privacy notes
## Test evidence            (tests run, screenshots/visual evidence for UI)
## Follow-ups / next steps
```

Be concrete and reference files. Do not overstate confidence — say explicitly what was and was not verified.
