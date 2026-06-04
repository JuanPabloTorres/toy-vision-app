---
description: Root-cause investigation of a real error — evidence first, no fixes until cause is proven.
argument-hint: <síntoma / error / stack trace>
---

Investigate this problem to root cause: $ARGUMENTS

**Iron law: no fix is proposed until the root cause is proven with evidence.**

Phases:
1. **Investigate** — reproduce; gather the exact error, stack, and the code path. Use codegraph trace/callers to follow the chain.
2. **Analyze** — read the involved files fully. Map state → service → inference → UI flow.
3. **Hypothesize** — list candidate causes; rank by likelihood; cite file:line for each.
4. **Confirm** — identify the single proven root cause and the evidence that confirms it.

Only after the cause is proven, propose a minimal fix with: objective, files affected, risk, test plan, expected result. Do not apply it without user approval.

Special care: if the cause is in camera, frame loop, inference, or overlay, include latency/memory/FPS impact in the analysis.
