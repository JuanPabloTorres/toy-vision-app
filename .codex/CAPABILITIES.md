# Codex capability notes

Validated locally with `codex-cli 0.157.1` on Windows:

- root `AGENTS.md` is the native persistent project-guidance mechanism;
- project custom agents use `.codex/agents/*.toml` with `name`, `description`,
  and `developer_instructions`;
- repository skills are discovered from `.agents/skills/*/SKILL.md`;
- multi-agent support is present and reported stable by `codex features list`;
- project configuration uses `.codex/config.toml` after the repository is
  trusted;
- skill changes are automatically detected by current Codex, but a restart is
  the documented recovery if new skills do not appear.

Real limitations:

- arbitrary project slash aliases such as `/diagnose-auto-collection` are not
  a documented native facility. `.codex/commands/*.md` therefore remain
  auditable recipes and point to native `$toyvision-*` skill invocations;
- creating a TOML agent does not force delegation. The user, `AGENTS.md`, or an
  active skill must request subagents, and the runtime/permissions must allow it;
- a new read-only `codex exec` session successfully reported repository
  `AGENTS.md`, skill `toyvision-false-collection-investigation`, and custom
  agent `yolo_debugger` through native discovery;
- `codex doctor` currently reports an elevated Windows sandbox provisioning
  failure plus Defender/Dev Drive warnings. These are host-environment findings,
  not `.codex` content errors, but may affect isolated local runs;
- `integration_test/` is absent. Existing `test/integration/**` tests execute on
  the host and do not replace physical CameraX/device automation.

The deterministic project validator is:

```powershell
.\.codex\scripts\validate-environment.ps1
```

It checks required structure, agent fields, skill manifests/sections,
cross-references, command-to-skill routing, broken local Markdown links, and
production `ToyCollected` ownership.
