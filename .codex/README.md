# Toy Vision engineering environment

This directory is the project control plane for future Codex work. It describes
the current implementation, routes work to executable project agents and
skills, and defines evidence required before a claim can be marked `PASS`.

## Native Codex conventions used

- Root `AGENTS.md` is the always-loaded project entry point.
- `.codex/agents/*.toml` are native project-scoped custom agents.
- `.agents/skills/*/SKILL.md` are native repository skills and are invoked as
  `$toyvision-<name>` or selected implicitly from their descriptions.
- `.codex/config.toml` caps child-agent concurrency. Multi-agent execution still
  requires an explicit user request or applicable project/skill instruction.
- `.codex/commands/*.md` are reviewed workflow recipes, not fake executables.
  Current Codex does not expose arbitrary project slash aliases such as
  `/diagnose-auto-collection`. Use the executable skill named in each recipe.
  Enabled skills can appear in the slash picker, but their portable invocation
  is `$skill-name`.

Project `.codex/config.toml` layers are loaded only for repositories the local
Codex client trusts. Start a new trusted project session after checkout or
after adding skills/agents so discovery refreshes. See `CAPABILITIES.md`.

## Start here

| Need | Agent | Executable skill | Read first | Primary evidence |
|---|---|---|---|---|
| Route a complex change | `toy_vision_orchestrator` | task-specific | `DEVELOPMENT_WORKFLOW.md` | integrated verdict |
| Architecture/debt | `architect` | `$toyvision-architecture-audit` | `ARCHITECTURE.md` | dependency/owner map |
| Full perception failure | `perception_engineer` | `$toyvision-perception-debugging` | `knowledge/perception-pipeline.md` | first incorrect state |
| YOLO marks everything | `yolo_debugger` | `$toyvision-yolo-tflite-debugging` | `knowledge/model-contracts.md` | pixels→raw→decoded trace |
| False/auto collection | `false_collection_specialist` | `$toyvision-false-collection-investigation` | `knowledge/cleanup-invariants.md` | event→evidence causal chain |
| ID switch/duplicate track | `tracking_engineer` | `$toyvision-tracking-reidentification` | `knowledge/tracking-model.md` | association matrix/history |
| Disappearance ambiguity | `tracking_engineer` | `$toyvision-disappearance-verification` | `knowledge/cleanup-invariants.md` | rejection reasons/window |
| Scene pan/shake | `perception_engineer` | `$toyvision-scene-stability` | `knowledge/perception-pipeline.md` | scene trace |
| Gameplay feels flat | `gameplay_engineer` | `$toyvision-flutter-gameplay-ui` | `knowledge/gameplay-flow.md` | complete child flow |
| Flutter/rebuild issue | `flutter_ui_engineer` | `$toyvision-flutter-gameplay-ui` | `PRODUCT_RULES.md` | widget/lifecycle validation |
| Rive/Lottie/3D | `animation_3d_engineer` | `$toyvision-rive-animation` or `$toyvision-gltf-3d` | `knowledge/gameplay-flow.md` | domain-event reaction |
| Slow/hot Android | `android_performance_engineer` | `$toyvision-performance-profiling` | `QUALITY_GATES.md` | real-device profile |
| Replay regression | `test_engineer` | `$toyvision-replay-testing` | `knowledge/testing-scenarios.md` | reproducible replay |
| Deliberate break test | `adversarial_qa` | `$toyvision-adversarial-testing` | `knowledge/testing-scenarios.md` | scenario matrix |
| Refactor | `architect` | `$toyvision-clean-code-refactor` | `ARCHITECTURE.md` | owner/consumer proof |
| Release decision | `release_auditor` | `$toyvision-release-certification` | `QUALITY_GATES.md` | independent verdict |

## Source of truth precedence

1. Executable code and tests in the current working tree.
2. `.codex/PRODUCT_RULES.md`, `.codex/ARCHITECTURE.md`, and
   `.codex/QUALITY_GATES.md`.
3. Current `docs/certification_harness.md`, `docs/real_device_validation.md`,
   and `docs/ultralytics_dependency_audit.md`.
4. `.toyvision/` only where it agrees with the current implementation.
   Several active files there still describe deleted `KidGameController`,
   label mapping, count-window progress, and human-confirmed completion.
5. `.toyvision/archive/` is historical research, never production authority.

## Status vocabulary

- `PASS`: every applicable gate has direct, current evidence.
- `PARTIAL`: meaningful evidence passes but required gates remain absent.
- `FAIL`: executed evidence violates an acceptance criterion.
- `BLOCKED`: the gate could not run because a required device, dataset,
  credential, decision, or external dependency is unavailable.

The environment itself can be usable while the product release remains
`PARTIAL`. See `AUDIT.md` for the observed repository classification.
