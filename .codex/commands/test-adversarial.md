# `test-adversarial` recipe

Native invocation: `$toyvision-adversarial-testing`.

Use `.codex/knowledge/testing-scenarios.md`. Execute every available focused,
integration, replay, corpus, and device check. Return one row per scenario with
exactly `PASS`, `FAIL`, `NOT_EXECUTED`, or `BLOCKED_DEVICE`, plus evidence path
and unexpected events/IDs. Never collapse missing rows into PASS.
