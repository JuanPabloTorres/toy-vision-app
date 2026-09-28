---
name: toyvision-clean-code-refactor
description: Refactor Toy Vision ownership, naming, duplication, cohesion, and dead code without adding parallel patches or changing behavior silently.
---

# PURPOSE

Improve maintainability through a small owner-aware migration, not patches over
patches.

# WHEN TO USE

Use for extraction, renaming, consolidation, duplicate logic, god classes,
obsolete adapters, or code-health work with behavior intended to stay stable.

# INPUTS

- Target smell and preserved behavior.
- Owner, callers/consumers, duplicates, contracts, tests, and current git diff.

# PROCEDURE

1. Locate the authoritative owner, all consumers, duplicate implementations,
   contracts, and tests before editing.
2. Capture a baseline with focused tests and observable behavior.
3. Define the smallest end state and migration order; avoid speculative
   abstractions.
4. Move/change one responsibility at a time without creating a second truth
   path.
5. Delete replaced/dead implementation and update imports/tests/docs in the
   same change.
6. Search for stale symbols and event constructors.
7. Run architecture audit, formatter, analyzer, focused and full regressions.

# TOOLS

`rg`, Git diff/status, `$toyvision-architecture-audit`, Dart formatter, Flutter
analyzer/tests, and `.codex/templates/implementation-plan.md`.

# EXPECTED OUTPUT

Owner/consumer map, preserved behavior, focused diff, removed code list,
validation evidence, and residual debt explicitly out of scope.

# FAILURE CONDITIONS

Fail if old and new paths coexist, public contracts change silently, unrelated
files are reformatted, tests are weakened, or security/privacy gates are
relaxed to simplify code.

# QUALITY GATES

No stale symbols/duplicate owner; architecture gate; format/analyze; focused
and full tests; replay/adversarial gates when perception/gameplay is touched.
