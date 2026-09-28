---
name: toyvision-architecture-audit
description: Audit Toy Vision layer boundaries, ownership, event origins, coupling, and migration risk before structural changes or architecture verdicts.
---

# PURPOSE

Establish the observed architecture and smallest safe correction without
rewriting the product or accepting duplicated owners.

# WHEN TO USE

Use for module moves, new services, dependency inversions, god classes,
duplicate state, architecture debt, or changes spanning two or more layers.

# INPUTS

- Requested behavior and files/change set.
- `AGENTS.md`, `.codex/ARCHITECTURE.md`, and current `git status`.
- Entry points, imports, providers, event constructors, consumers, and tests.

# PROCEDURE

1. Map entry point → state owner → domain decision → adapters → UI.
2. Build the import and control-flow edges for affected files.
3. Locate all owners/constructors of the changed state or event with `rg`.
4. Compare observed edges with the intended direction; record existing debt
   separately from debt introduced by the change.
5. Identify duplication, leaky abstractions, cycles, god classes, and
   infrastructure/presentation coupling with file/symbol evidence.
6. Recommend the smallest migration, its compatibility plan, and deletion of
   the replaced path.
7. Define focused tests plus static/architecture gates.

# TOOLS

Use `rg --files`, `rg -n '^import ' lib`, `rg -n 'ToyCollected\(' lib`, Git
diff/status, Flutter analyzer, and affected tests. Use
`.codex/templates/implementation-plan.md` for a migration.

# EXPECTED OUTPUT

Observed architecture, strengths, risk-ranked findings, evidence, proposed
owners/contracts, minimal migration steps, and validation commands.

# FAILURE CONDITIONS

Fail the audit if event ownership is ambiguous, the proposed dependency points
outward from domain, the old path survives as parallel truth, or conclusions
lack file/symbol evidence.

# QUALITY GATES

No new inversion; one owner per decision; production `ToyCollected` remains in
`CleanupSessionService`; format/analyze and relevant regressions pass.
