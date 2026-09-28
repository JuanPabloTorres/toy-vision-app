# Agent Routing — ToyVision Real-Time

Before starting any work, determine which agent **owns** the task. The owning agent's
file in [agents/](agents/) defines its rules and what it must reject.

## Routing table

| Task / area | Owning agent |
|-------------|--------------|
| Product scope, MVP order, user value | [product-architect-agent](agents/product-architect-agent.md) |
| Architecture, technology, module structure | [solution-architect-agent](agents/solution-architect-agent.md) |
| Camera, frame stream, inference throttling, live loop, performance | [flutter-realtime-agent](agents/flutter-realtime-agent.md) |
| Visual consistency, interaction, screen states, accessibility | [ui-ux-agent](agents/ui-ux-agent.md) |
| Reusable components, design tokens, shared patterns | [component-system-agent](agents/component-system-agent.md) |
| Validation, snapshot quality, progress, energy, completion invariants | [business-logic-agent](agents/business-logic-agent.md) |
| Dataset, model selection, training, export, evaluation, versioning | [ai-vision-model-agent](agents/ai-vision-model-agent.md) |
| Unit tests, product scenarios, performance + privacy validation | [qa-validation-agent](agents/qa-validation-agent.md) |
| Final review: maintainability, boundaries, naming, duplication, safety | [code-review-agent](agents/code-review-agent.md) |

## Multi-agent tasks

A task may touch several layers. When it does:

1. The Solution Architect Agent sequences the work across owning agents.
2. Each owning agent handles its layer using the agent response standard.
3. The Code Review Agent reviews the combined result against boundaries and safety.

## Agent response standard

Every agent responds with this format **before** making changes:

```text
Objective:
Relevant agent:
Relevant skills:
Files to create or modify:
Architecture impact:
Business logic impact:
UI/UX impact:
Privacy impact:
Implementation steps:
Tests required:
Acceptance criteria:
Risks:
```

## Skills

Each agent applies the relevant guardrail skills in [skills/](skills/) for the area it
touches. Skills are constraints; agents are owners.
