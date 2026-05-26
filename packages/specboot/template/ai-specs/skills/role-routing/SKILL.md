---
name: role-routing
description: Decision tree for picking the right transversal role (orchestrator | explorer | architect | implementer | reviewer) or domain consultant for a given request. Use when unsure which role to invoke, or when teaching a new contributor the multi-agent flow.
author: LIDR.co
version: 1.0.0
---

# role-routing Skill

Reference for `docs/base-standards.md` §8. Use this skill any time you are about to invoke a `Task(subagent_type: ...)` and want to confirm the choice.

## Decision tree

```
Is this a non-trivial change (>3 steps OR touches >1 module OR needs discovery)?
├── NO  → act as implementer directly; skip delegation.
└── YES → start with orchestrator. Then follow:

   Need to read/map unfamiliar code or find existing utilities?
   → explorer (breadth: quick | medium | thorough)

   Need to decide files, interfaces, contracts, build order?
   → architect (requires at least one explorer report for non-trivial work)

   Need to write code or tests for ONE scoped task?
   → implementer (requires architecture.md, unless orchestrator opt-out)

   Need to validate work vs spec + standards + blueprint?
   → reviewer (mode: verify | adversarial)

   Need stack-specific advice (React patterns, Prisma, scikit-learn, etc.)?
   → domain consultant: <pack-agent-name>
       e.g. frontend-developer, backend-developer,
            data-scientist, data-engineer
```

## Quick lookup by slash command

| Command              | Primary role(s)                                          |
| -------------------- | -------------------------------------------------------- |
| `/enrich-us`         | orchestrator → explorer (optional) → domain consultant   |
| `/ff` (or `/new`)    | orchestrator → architect → domain consultant             |
| `/apply`             | orchestrator → implementer (per task) → reviewer at end  |
| `/verify`            | reviewer (mode: verify)                                  |
| `/adversarial-review`| reviewer (mode: adversarial)                             |
| `/archive`           | orchestrator                                             |
| `/commit`            | orchestrator (no delegation; uses `commit` skill)        |

## Red flags

- Implementer about to design → STOP. Return to orchestrator; orchestrator decides whether to re-invoke architect.
- Reviewer about to apply a fix → STOP. Reviewer reports only.
- Architect about to write production code or tests → STOP. Only design docs.
- Orchestrator about to edit a file → STOP. Delegate.
- Working on >1 task in parallel → STOP. Per `base-standards.md` §1, one task at a time. (Multiple parallel `explorer` calls inside one planning step are the only exception.)

## Brief template for `Task` invocations

Every subagent is stateless. Include:

1. Role and mode (e.g. "reviewer in adversarial mode").
2. Feature name and `.claude/doc/<feature>/` path.
3. Active pack (`web` | `data-science` | ...).
4. Specific question or task scope.
5. Required inputs (paths to spec, architecture.md, exploration reports).
6. Expected output path and format.
