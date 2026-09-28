# Development workflow

1. Inspect `git status` and preserve unrelated work.
2. Route the request using `.codex/README.md`; load only relevant knowledge and
   the matching skill.
3. Reproduce or establish a baseline. Capture observable state, not a guessed
   cause.
4. Trace the real owner, callers, consumers, contracts, and tests.
5. For perception defects, locate the first incorrect state before changing a
   threshold.
6. Write an implementation plan with acceptance evidence. Assign only one
   writer to each owner.
7. Implement the smallest coherent correction. Remove replaced code rather
   than accumulating parallel paths.
8. Run focused tests, replay the original failure, then run applicable gates.
9. Have a separate reviewer/agent perform adversarial or release evaluation
   when the user requests multi-agent execution or the active skill requires it.
10. Report `PASS`, `PARTIAL`, `FAIL`, or `BLOCKED`, including unexecuted gates.

## Multi-agent orchestration

The native orchestrator is `toy_vision_orchestrator`. Custom agents are under
`.codex/agents/`. Delegation should keep read-heavy diagnosis/review independent
from the single implementation owner.

For “Toy Vision is collecting by itself”:

```text
toy_vision_orchestrator
→ adversarial_qa (reproduce and preserve trace)
→ false_collection_specialist (reverse causal chain)
→ perception_engineer or tracking_engineer (identify owner/correction)
→ one implementation owner
→ test_engineer (focused + replay regression)
→ adversarial_qa (original + nearby scenarios)
→ release_auditor (independent verdict)
```

Subagents must not all edit the same files. Review agents should normally use a
read-only sandbox. The implementing agent never supplies the sole release
verdict.

## Definition of done

```text
implementation
+ architecture validation
+ focused and regression tests
+ observable behavior evidence
+ no known critical regression
+ all applicable gate results reported
```

For perception, passing code tests proves deterministic contracts only. It does
not prove real-world perception without a representative corpus and device run.
