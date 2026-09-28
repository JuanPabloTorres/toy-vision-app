---
name: toyvision-release-certification
description: Independently certify Toy Vision readiness from architecture, tests, replay/corpus, gameplay, device, performance, privacy, licensing, signing, and artifact evidence.
---

# PURPOSE

Issue an honest `PASS`, `PARTIAL`, `FAIL`, or `BLOCKED` without allowing the
implementation agent to self-certify.

# WHEN TO USE

Use for release readiness, feature-done claims, APK handoff, commercial claims,
or the `certify` workflow.

# INPUTS

- Scope/diff and implementation evidence from a separate owner.
- Static/full test output, replay/adversarial matrix, corpus report.
- APK/model hashes, supported-device run, performance/privacy evidence.
- dependency/model/asset licenses, app ID/signing status, known risks.

# PROCEDURE

1. Confirm evidence belongs to the exact current source/artifact.
2. Evaluate every row in `.codex/QUALITY_GATES.md`; do not collapse blocked or
   unexecuted rows.
3. Re-run safe local gates and inspect event origins/import boundaries.
4. Validate corpus completeness before accepting accuracy metrics.
5. Require physical target-device evidence for CameraX/TFLite, thermal,
   battery, audio/haptics, Rive/3D, and physical interaction claims.
6. Verify privacy defaults, commercial rights, production app ID/signing, and
   residual critical defects.
7. Write `.codex/templates/final-verdict.md` with one status and conditions to
   advance.

# TOOLS

Git/status/diff, Flutter/Dart gates, certification harness and reports, Galaxy
script outputs, Android manifest/dependency inspection, hashes and license docs.

# EXPECTED OUTPUT

Gate-by-gate evidence table, independent verdict, blockers/failures, residual
risks, and precise next evidence required.

# FAILURE CONDITIONS

`PASS` is forbidden if any applicable gate fails/is blocked, any critical
regression is known, corpus/device evidence is missing, commercial licensing is
unresolved, app signing is non-production, or evidence is stale/mismatched.

# QUALITY GATES

All gates in `.codex/QUALITY_GATES.md` are PASS. Otherwise issue PARTIAL, FAIL,
or BLOCKED as defined in `.codex/README.md`.
