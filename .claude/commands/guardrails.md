---
description: Check a change against ToyVision project rules before/after applying it.
argument-hint: [archivos o descripción del cambio]
---

Verify that the proposed or applied change does NOT break ToyVision project rules. Target: ${ARGUMENTS:-current diff}

Note: this is the *project rule check*. For the global edit-safety "guard mode" skill (destructive-command warnings + directory-scoped edits), use `/guard`.

Checklist (reject or flag any violation, cite file:line):
- [ ] Impact analyzed before changing code (objective / files / risk / test plan / expected result present).
- [ ] No edits to camera, frame loop, inference, or overlay without a performance review (latency, memory, FPS, throttling).
- [ ] No duplicated visual components — reuse `lib/ui/components/`.
- [ ] No business logic inside widgets.
- [ ] Layer separation intact: UI / state / services / inference / storage / validation.
- [ ] Descriptive names; no abbreviated/cryptic identifiers.
- [ ] Privacy: local-first; no image upload without explicit consent.
- [ ] AI/model change versions dataset/model/export if applicable.
- [ ] Tests added/updated for the change.

Output: PASS / FAIL per item with evidence, then an overall verdict. Do not auto-fix; report only.
