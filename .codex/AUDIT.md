# Repository audit and classification

Audit basis: current working tree on 2026-09-27. The tree already contained a
large uncommitted architecture migration; this environment treats it as the
current implementation and does not overwrite or delete unrelated work.

## Classification

| Area | Decision | Evidence |
|---|---|---|
| Existing `.codex/` | CREATE | directory was absent |
| Root `AGENTS.md` | CREATE | required native discovery entry point was absent |
| `.codex/agents/*.toml` | CREATE | native project custom-agent convention |
| `.agents/skills/*/SKILL.md` | CREATE | native repo-skill discovery convention |
| `.codex/commands/*.md` | CREATE | recipes only; arbitrary slash aliases are unsupported |
| `lib/domain/**` | KEEP + IMPROVE | clear entities/invariants; two imports from `core/math` weaken pure-domain target |
| `lib/perception/**` | KEEP + IMPROVE | real staged pipeline and traces; needs real-corpus calibration/coverage |
| `lib/application/**` | KEEP + IMPROVE | authorized event owner exists; controller composes concrete infrastructure |
| `lib/infrastructure/**` | KEEP + IMPROVE | useful adapters/recording; feedback coordinator crosses into presentation |
| `lib/presentation/**` | KEEP + IMPROVE | child/debug split and domain feedback exist; 540-line cleanup screen is a concentration risk |
| `lib/ui/**` | MERGE LATER | remaining tokens/components overlap presentation ownership |
| automated `test/**` | KEEP + IMPROVE | 34 tests passed during validation; synthetic replays still do not cover the full physical adversarial matrix |
| `integration_test/` | CREATE WHEN DEVICE FLOW IS AUTOMATABLE | directory absent; current `test/integration` is host-side |
| `tools/toyvision_certify.dart`, `tools/certification/**` | KEEP | real corpus validation/evaluation entry points |
| `tools/certify_galaxy_s25.ps1` | KEEP | real-device gate with model rejection and evidence capture |
| `tools/toy_model_export/**` | KEEP + GOVERN | reproducible export assets/logs; large binaries and AGPL provenance matter |
| `assets/models/cleanup_items.tflite` | KEEP + BLOCK COMMERCIAL | bundled 62,764,989-byte model; licensing unresolved |
| Rive/Lottie/glTF/audio assets | KEEP + VERIFY DEVICE | local fallbacks/tests exist; physical behavior unverified |
| Android config | IMPROVE BEFORE RELEASE | camera/privacy choices are explicit; app id TODO and debug signing remain |
| `docs/certification_harness.md` | KEEP | current operational authority |
| `docs/real_device_validation.md` | KEEP | physical matrix and existing blocker |
| `docs/ultralytics_dependency_audit.md` | KEEP | commercial license boundary |
| `docs/sow_architecture_audit.md` | KEEP AS MIGRATION HISTORY | describes pre-migration state, not current architecture |
| `docs/sow_implementation_evidence.md` | IMPROVE | useful evidence, but its claim that open-set creates a stable track conflicts with current test/implementation contract |
| active `.toyvision/**` | MERGE/DEPRECATE | several files still name deleted label/count/KidGame paths; retain during dirty-tree migration but do not treat as current authority |
| `.toyvision/archive/**` | KEEP AS HISTORY | never wire into production without an explicit decision |

## Highest-impact findings

1. Release remains blocked by physical-device evidence, a complete real corpus,
   commercial detector licensing, and release signing.
2. Existing automation strongly covers invariants but the adverse replay corpus
   contains one 25-frame synthetic scenario, far short of the required matrix.
3. Architecture direction is good but composition roots leak across layers.
4. Legacy governance conflicts with current code and can misroute future agents.
5. Runtime labels are diagnostic-only in current production decision code; this
   invariant is demonstrably enforced by tests and must remain so.

No legacy `.codex` files were deleted because none existed. Existing modified
`.toyvision` files were not deleted to avoid destroying unrelated user work.
