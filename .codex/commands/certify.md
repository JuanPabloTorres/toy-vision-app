# `certify` recipe

Native invocation: `$toyvision-release-certification` using the read-only
`release_auditor` agent after implementation and adversarial review.

Evaluate every gate in `.codex/QUALITY_GATES.md` against exact source/artifact
evidence. Require a complete corpus, supported Galaxy run, privacy/license/app
ID/signing resolution, and independent verdict. Use
`.codex/templates/final-verdict.md`; anything short of all applicable PASS is
`PARTIAL`, `FAIL`, or `BLOCKED`.
