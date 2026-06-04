---
description: Structural audit — architecture, naming, duplication, layer boundaries, risks.
argument-hint: [módulo o ruta opcional; vacío = todo lib/]
---

Run a **read-only structural audit** of: ${ARGUMENTS:-lib/}

Do NOT modify code. Use codegraph (callers/callees/impact) and Grep to gather evidence.

Check and report:
1. **Layer boundaries** — UI / state / services / inference / storage / validation kept separate. No business logic inside widgets. No inference logic leaking into UI.
2. **Duplication** — repeated visual components that should reuse `lib/ui/components/`; repeated logic that should be a service/util.
3. **Naming** — descriptive, no abbreviated/cryptic identifiers.
4. **Performance hotspots** — camera, frame loop, inference, overlay: allocations per frame, missing throttling/single-inflight guards.
5. **Privacy** — local-first processing; no image upload paths without explicit consent.
6. **Risks** — concrete, file:line referenced.

Output: findings grouped by severity (high / medium / low), each with file:line and a one-line recommendation. No fixes applied — propose only.
