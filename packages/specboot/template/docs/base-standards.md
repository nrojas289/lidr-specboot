---
description: Universal development rules and guidelines for any project bootstrapped with lidr-specboot. Applies to all AI agents (Claude, Cursor, Codex, Gemini, etc.) regardless of the chosen domain pack.
alwaysApply: true
---

## 1. Core Principles

- **Small tasks, one at a time**: Always work in baby steps. Never go forward more than one step.
- **Test-Driven Development**: Start with failing tests for any new functionality (TDD), according to the task details. See pack-specific standards for how TDD applies in non-code-product contexts (e.g., notebooks).
- **Type Safety**: All code must be fully typed (TypeScript `strict`, Python `mypy --strict`, equivalent in other languages).
- **Clear Naming**: Use clear, descriptive names for variables, functions, modules, and artifacts.
- **Incremental Changes**: Prefer incremental, focused changes over large modifications.
- **Question Assumptions**: Always question assumptions and inferences.
- **Pattern Detection**: Detect and highlight repeated patterns.

## 2. Language Standards

- **English Only**: All technical artifacts must use English, including:
    - Code (variables, functions, classes, comments, error messages, log messages)
    - Documentation (README, guides, API/data docs)
    - Tickets (titles, descriptions, comments)
    - Data schemas, dataset names, database names
    - Configuration files and scripts
    - Git commit messages
    - Test names and descriptions
    - Notebook narrative and section headers

## 3. Domain Packs

This project is configured with one or more **domain packs** that live in `docs/` (standards) and `ai-specs/agents/` (agents). Each pack adds standards and agents specific to a stack (e.g., `web`, `data-science`).

- The active pack(s) declare themselves in `docs/<pack>-standards.md` and an optional `docs/pack-context.md`.
- Always load the active pack's standards alongside this file before starting work.
- Available official packs: `web`, `data-science`. Roadmap: `data-engineering`, `backend-api`, `cli-lib`.

Refer to:

- [Documentation Standards](./documentation-standards.md) — technical documentation structure, formatting, and maintenance guidelines.
- [OpenSpec Tasks Mandatory Steps](./openspec-tasks-mandatory-steps.md) — required checklist when creating or updating OpenSpec `tasks.md` files.
- `docs/<pack>-standards.md` for any pack installed in this project.

## 4. Project Skills

- Skills live in `ai-specs/skills`.
- When a request matches a skill, load and follow the corresponding `SKILL.md` automatically before continuing.
- Also load any referenced files in the skill folder (e.g., `references/*.md`) when the skill requires them.

## 5. Planning Model Requirement

Planning workflows must run with Opus high reasoning. This applies to:

- `enrich-us`
- `openspec-ff-change`
- `openspec-continue-change`

Before starting any of these workflows, verify the session is using Opus high reasoning. If it is not, **self-correct** by adding `"model": "claude-opus-4-7"` to `.claude/settings.json` (use the `update-config` skill or edit directly), then continue — do not stop and ask the user. Revert to Sonnet medium for any other step.

## 6. Symlink Integrity and Multi-Agent Portability

- **Canonical Source**: Keep reusable artifacts in `ai-specs` as the canonical source. Agent-specific paths (such as `.claude` and `.cursor`) should reference them through symlinks when possible.
- **Update Safety**: Whenever a file is renamed, moved, or its suffix changes, verify and update all symlinks that target it before considering the change complete.
- **New Artifact Linking**: Whenever creating a new artifact that requires multi-agent exposure (new agents or skills), create the corresponding symlinks from the expected agent-specific reference paths.
- **External Customization Review**: Whenever customization is introduced outside `ai-specs`, evaluate whether it should be moved into `ai-specs` and replaced with symlinks from the original locations.
- **Completion Gate**: A change is incomplete if it leaves broken symlinks, stale targets, or duplicated canonical artifacts across agent-specific folders.

## 7. Mandatory OpenSpec Artifact Updates for Post-Apply Changes

When a new fix/change request appears after `opsx:apply` (or `/apply`) and before `opsx:archive` (or `/archive`), agents must treat it as a spec update first, not as an informal "fix this quickly". Documentation is the source of truth in OpenSpec.

Required order:

1. Update the current OpenSpec change artifacts affected (scenarios, requirements/specs, `tasks.md`). Do not add tasks as "bugfixes" but as part of the initial design, in the proper section.
2. If artifact regeneration is needed, run the corresponding OpenSpec step (`opsx:continue`, `opsx:ff`, or equivalent) before coding.
3. Implement code only after artifacts reflect the new request.
4. Re-run verification against the updated artifacts before archiving.

Do not apply direct code-only fixes in this window without updating OpenSpec artifacts.

## 8. Multi-Agent Execution Model

Non-trivial work is executed by **five transversal roles** living in `ai-specs/agents/`, plus the active pack's **domain agents** used as consultants.

| Role           | Lane                                                                                                            |
| -------------- | --------------------------------------------------------------------------------------------------------------- |
| `orchestrator` | Decomposes the US, maintains the living plan, delegates, decides closure. NEVER edits code.                     |
| `explorer`     | Read-only. Maps code, finds reuse, traces dependencies. NEVER proposes solutions.                               |
| `architect`    | Produces `.claude/doc/<feature>/architecture.md` (files, interfaces, contracts, build sequence). NEVER codes.   |
| `implementer`  | Executes one task with TDD, strictly following the blueprint. NEVER designs. NEVER closes.                      |
| `reviewer`     | Validates vs spec + standards + blueprint. Severities: blocker/major/minor/nit. NEVER applies fixes.            |

**Invocation**: use the `Task` tool with `subagent_type: orchestrator|explorer|architect|implementer|reviewer` for roles, and `subagent_type: <pack-agent-name>` for domain consultants (e.g. `frontend-developer`, `data-scientist`). Each invocation is a fresh, stateless subagent — briefs must be self-contained.

**Gate**: `/apply` must not route any `implementer` task until `.claude/doc/<feature>/architecture.md` exists, unless the orchestrator records an explicit opt-out line for a trivial task (<3 steps, one unit, no new files).

**No-cross rules**:

- `reviewer` never implements; `implementer` never designs; `architect` never writes production code or tests; `explorer` never edits anything except its own report; `orchestrator` never edits code.
- `implementer` MUST stop and return control to `orchestrator` when the blueprint mismatches reality. Re-planning is the `orchestrator`'s responsibility (which may re-invoke `architect`).
- Closure of a task requires either a passing `reviewer` report or, for trivial tasks, the orchestrator's documented gate decision plus green tests/lint.

**When to skip the model**: trivial single-step changes (typo, one-line config, rename in one file) can be done by the active agent acting as implementer without delegation. For anything that touches more than one module or requires discovery, delegation is mandatory.

**Role routing**: see the `role-routing` skill for the decision tree.

