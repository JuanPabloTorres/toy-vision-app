---
name: toyvision-adversarial-testing
description: Execute and report Toy Vision's required adverse camera, scene, object, identity, lifecycle, UI, and device scenarios with explicit per-scenario status.
---

# PURPOSE

Deliberately break assumptions and expose false positives, false/duplicate
collections, premature completion, ID switches, crashes, and UI dead ends.

# WHEN TO USE

Use after perception/tracking/gameplay fixes, before release, or when asked for
`test-adversarial` behavior.

# INPUTS

- Change/failure claim, build/model/APK hash, expected event rules.
- Scenario matrix from `.codex/knowledge/testing-scenarios.md`.
- Available automated fixtures, annotated corpus, and physical device.

# PROCEDURE

1. Select all scenarios adjacent to the changed evidence or state transition.
2. Run every automatable unit/integration/replay scenario and preserve logs.
3. Run corpus scenarios only with complete annotations and split isolation.
4. Mark physical-only rows `BLOCKED_DEVICE` when no supported device exists;
   never infer them from desktop results.
5. For each row record PASS, FAIL, NOT_EXECUTED, or BLOCKED_DEVICE plus event,
   track, crash, UI, and performance evidence.
6. Investigate any unexpected collection/completion as critical.
7. Produce a regression report; do not edit the implementation when acting as
   independent QA.

# TOOLS

Flutter test suites, replay fixture, certification harness/corpus report,
developer overlay/JSONL traces, ADB and Galaxy certification script.

# EXPECTED OUTPUT

Complete scenario matrix, reproduction details for failures, evidence paths,
severity, unexecuted reasons, and aggregate verdict.

# FAILURE CONDITIONS

Any unexplained `ToyCollected`, duplicate collection, empty/zero-progress
completion, crash, or child-flow dead end is FAIL. Missing device evidence is
BLOCKED_DEVICE, never PASS.

# QUALITY GATES

All applicable scenarios have explicit statuses; critical failures are zero;
static/full tests pass; release audit consumes the matrix independently.
