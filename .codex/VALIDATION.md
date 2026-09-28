# Environment validation record

Date: 2026-09-27

Host: Windows, `codex-cli 0.157.1`, Flutter 3.47.5, Dart 3.13.4

## Results

| Check | Result | Evidence |
|---|---|---|
| deterministic environment validator | PASS | 13 agents, 16 skills, 10 command recipes; required paths/fields/sections/links/routing/event ownership valid |
| official skill `quick_validate.py` | PASS | all 16 skills valid via `uv run --with pyyaml` |
| new-session native discovery | PASS | `AGENTS.md`, `toyvision-false-collection-investigation`, and `yolo_debugger` reported available |
| Flutter analyzer | PASS | 0 issues in 95.2 s |
| full Flutter suite | PASS | 34 tests |
| desktop replay benchmark | PASS (desktop only) | 25 frames; wall p95 66.56 ms; analysis p95 48.18 ms; RSS +35.71 MB |
| example certification manifest | BLOCKED as designed | missing validation/test splits, scenario tags, capture, and annotations; `flutter pub run` wrapper exit 1 |
| whitespace scan of new files | PASS | no trailing whitespace |
| physical Galaxy/device | BLOCKED/NOT EXECUTED | no supported physical certification run in this task |
| real representative corpus | BLOCKED/NOT EXECUTED | no complete dataset supplied |
| commercial release | BLOCKED | Ultralytics licensing, app ID and production signing unresolved |

## Discovery smoke limitation

The fresh Codex session discovered the project resources before invoking shell
tools. Its attempt to inspect paths through its own read-only shell failed with
`helper_sandbox_lock_failed` / Windows ACL error for
`C:\Users\estju\.codex\.sandbox-bin`. `codex doctor` independently reports the
elevated Windows sandbox failure plus Defender and non-Dev-Drive warnings.
This is a host provisioning limitation, not a broken project resource.

## Verdict

`.codex` governance environment: **PASS**. It is discoverable, internally
validated, and routes executable native skills/custom agents with honest
capability boundaries.

Toy Vision commercial release: **PARTIAL/BLOCKED**, for the device, corpus,
licensing, app ID, and signing reasons above. The environment intentionally
does not convert those product blockers into PASS.
