# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

`lidr-specboot` is a **portable AI-agent configuration template** that bootstraps Spec-Driven Development (OpenSpec) in any project. It ships:

- `docs/base-standards.md` — universal, stack-agnostic rules (single source of truth)
- `docs/packs/<pack>/` — domain packs (standards + examples per stack). Official packs: `web`, `data-science`. Roadmap: `data-engineering`, `backend-api`, `cli-lib`.
- `ai-specs/agents/` — agnostic agents shared across packs
- `ai-specs/packs/<pack>/agents/` — pack-specific agents
- `ai-specs/skills/` — reusable, pack-agnostic skill prompts
- `packages/specboot/` — the `@lidr/lidr-specboot` npm package (installs base + chosen pack via `npx`)
- Copilot config files (`CLAUDE.md`, `AGENTS.md`, `codex.md`, `GEMINI.md`) that **all symlink to `docs/base-standards.md`** in target projects

### Domain packs

A target project picks one pack at init time (`--pack web|data-science|none`, default `web`). `init.js` copies base files plus the chosen pack's standards (into `docs/`) and agents (into `ai-specs/agents/`), then sets up symlinks. Existing projects on the legacy web-only layout can run `npx @lidr/lidr-specboot --migrate --pack <name>` to relocate legacy files into `docs/legacy/` non-destructively.

## Core Rules

All development follows `docs/base-standards.md`. Key constraints:

- **TDD**: write failing tests first
- **English only**: all code, comments, docs, commit messages
- **Small steps**: one task at a time, never skip ahead
- **Fully typed**: TypeScript everywhere
- **Planning workflows** (`enrich-us`, `openspec-ff-change`, `openspec-continue-change`) require **Opus high reasoning** — set `"model": "claude-opus-4-7"` in `.claude/settings.json` before starting, then revert to Sonnet

## Multi-Agent Execution Model

The base ships five **transversal role agents** (in `ai-specs/agents/`, copied into every project regardless of pack):

- `orchestrator` — owns the living plan, delegates, decides closure. Never edits code.
- `explorer` — read-only discovery. Never proposes solutions.
- `architect` — produces `.claude/doc/<feature>/architecture.md` (blueprint) before any implementer runs. Never codes.
- `implementer` — executes one task with TDD against the blueprint. Never designs.
- `reviewer` — validates vs spec + standards + blueprint. Modes: `verify`, `adversarial`. Never applies fixes.

Pack-specific agents (`frontend-developer`, `backend-developer`, `data-scientist`, `data-engineer`) act as **domain consultants** invoked by roles when stack-specific advice is needed. Full rules in `docs/base-standards.md` §8; routing decision tree in the `role-routing` skill.

## Symlink Architecture

`ai-specs/` is the canonical source. Agent-specific directories are symlinked from it:

```
.claude/agents/<name>   → ../../ai-specs/agents/<name>
.claude/skills/<name>   → ../../ai-specs/skills/<name>
.cursor/agents/<name>   → ../../ai-specs/agents/<name>
.cursor/skills/<name>   → ../../ai-specs/skills/<name>
```

**Completion gate**: a change is incomplete if it leaves broken symlinks or duplicated canonical artifacts. After any rename/move in `ai-specs/`, verify and update all impacted symlinks before closing the task.

## npm Package (`packages/specboot`)

The `init.js` script copies base files from `packages/specboot/template/` plus the chosen pack into a target project, then creates the symlink structure above. Safe to re-run — existing files are never overwritten. Supports `--pack <name>` (non-interactive), `--migrate` (relocate legacy layout), and `--help`.

```bash
# Publish a new version
cd packages/specboot
npm publish
```

No build step required. The package has no test runner configured — validate manually by running `node packages/specboot/bin/init.js <target-dir>` and checking `stats.errors`.

## OpenSpec Workflow (for target projects, not this repo)

```
/enrich-us <ticket>   # refine user story (Opus required)
/ff <ticket>          # generate feature file + tasks (Opus required)
/apply <ticket>       # implement tasks
/verify <ticket>      # validate against artifacts
/adversarial-review   # red-team review
/archive <ticket>     # archive change
/commit               # commit + PR
```

Post-`/apply` fix requests must update OpenSpec artifacts **before** touching code.

## Skills

Skills live in `ai-specs/skills/<name>/SKILL.md`. To add or modify a skill, use the `writing-skills` skill (`/writing-skills`), which enforces TDD-style validation before deployment. After any skill change, verify the symlinks in `.claude/skills/` and `.cursor/skills/` are intact.
