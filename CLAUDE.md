# CLAUDE.md — ToyVision Real-Time

Operating instructions for Claude Code in this repository. The full governance lives in
[.toyvision/](.toyvision/) — this file is the entry point and the non-negotiable rules.

## Product purpose

ToyVision is a mobile-first app that **detects, tracks, and counts toys live** from the camera.
It is **local-first and privacy-first**: inference runs on-device; images are never uploaded
without explicit consent.

- Stack: Flutter + Dart + Material 3, state via Riverpod.
- Local AI: YOLO exported to TFLite (behind a swappable detector interface).
- Phase 1 is **mock-first**: a deterministic mock detector drives the pipeline; the real
  camera + TFLite path is Phase 2. Check [.toyvision/](.toyvision/) for current phase scope.

## Architecture & layer boundaries

Strict separation — code belongs to exactly one layer:

| Layer | Location | Holds |
|-------|----------|-------|
| UI | `lib/ui/`, `lib/camera/screens/` | Presentation only, design tokens, reusable components |
| State | `lib/camera/*controller*`, Riverpod notifiers | UI state orchestration |
| Services | `lib/camera/services/` | Camera lifecycle, frame processing |
| Inference | `lib/detection/` | Detectors (strategy), raw detection models |
| Tracking + Validation | `lib/tracking/`, `lib/business/` | IoU tracking, rules, counting |
| Config | `lib/core/config/` | Single source of truth for thresholds |

Detection pipeline: **detector → validation rules → tracking → counting → UI overlay**.

## Mandatory protocol before modifying code

1. **Analyze impact first.** Route the task to its owning agent via
   [.toyvision/agent-routing.md](.toyvision/agent-routing.md) and respond in the agent
   response standard (objective, files, architecture/business/UI/privacy/performance impact,
   steps, tests, acceptance, risks) **before** editing.
2. Every change must state: **objective, files affected, risk, test plan, expected result.**
3. Use `/think` for analysis, `/spec` to specify, `/audit` to review structure, `/diagnose`
   for root-cause bugs, `/guardrails` to check rules, `/report` for findings, `/context` for
   orientation.

## Hard rules

- **Do not** touch camera, frame loop, inference, or overlay without a performance review:
  account for **latency, memory, FPS, and throttling**. Preserve the single-inflight guard.
- **Do not** duplicate visual components — reuse `lib/ui/components/`; add variants, not forks.
- **Do not** put business logic inside widgets. Widgets are presentation only.
- **Do not** add unnecessary packages or refactor beyond the task.
- Keep **descriptive names**; no abbreviated or cryptic identifiers.
- Respect layer separation (UI / state / services / inference / storage / validation).
- **Privacy:** local-first processing; never upload images without explicit consent.
- **AI/model changes** must version dataset / model / export and carry evaluation evidence.
  Do not change the TFLite model or its export without the user's go-ahead.
- **Testing:** every behavior change needs unit/scenario tests (use `lib/testing/` fixtures).
  Every visual change needs screenshot/visual evidence.
- **Git:** no automatic commits without explicit confirmation.

## Tooling

- **MCP servers** (`.mcp.json`): `playwright` (visual tests), `context7` (library docs),
  `codegraph` (semantic code intelligence — callers/impact), `ruflo` (multi-agent + memory).
  Some require a Claude Code restart to connect.
- **CodeGraph**: indexed; use for impact analysis before touching shared code.
- **Agents** (`.claude/agents/`): mirror [.toyvision/agents/](.toyvision/agents/) — route work
  to the owning agent. They propose and review; they do not bypass these rules.
