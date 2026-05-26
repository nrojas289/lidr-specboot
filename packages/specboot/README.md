# @lidr/lidr-specboot

Bootstrap Spec-Driven Development (OpenSpec + lidr-specboot) into any project.

## Install

```bash
# Interactive (asks which pack to install)
npx @lidr/lidr-specboot [target-dir]

# Non-interactive
npx @lidr/lidr-specboot [target-dir] --pack web
npx @lidr/lidr-specboot [target-dir] --pack data-science
npx @lidr/lidr-specboot [target-dir] --pack none

# Migrate a project on the legacy web-only layout
npx @lidr/lidr-specboot [target-dir] --migrate --pack data-science
```

`target-dir` defaults to the current working directory.

## What it does

1. Copies `docs/base-standards.md` and shared docs (universal rules).
2. Copies all `ai-specs/skills/*` (pack-agnostic workflows, including `role-routing`).
3. Copies the **five transversal role agents** (`orchestrator`, `explorer`, `architect`, `implementer`, `reviewer`) into `ai-specs/agents/`.
4. Copies the chosen pack's standards into `docs/` and its **domain agents** into `ai-specs/agents/`.
5. Creates symlinks: `CLAUDE.md`, `AGENTS.md`, `codex.md`, `GEMINI.md` → `docs/base-standards.md`; mirrors `ai-specs/agents/*` and `ai-specs/skills/*` into `.claude/` and `.cursor/`.

Safe to re-run: existing files are never overwritten; the run reports `copied`, `skipped`, `linked`, `moved`, `errors`.

## Available packs

| Pack            | Status   |
| --------------- | -------- |
| `web`           | ✅ stable (default) |
| `data-science`  | ✅ stable |
| `none`          | ✅ base + skills only |
| `data-engineering` / `backend-api` / `cli-lib` | 🗺️ roadmap |

See the top-level repo README for the full pack catalogue and roadmap.

## Migration

If a target project already has the legacy web-only layout (`docs/frontend-standards.md`, `docs/backend-standards.md`, etc. at the root of `docs/`), `init.js` detects it. Re-run with `--migrate --pack <name>` to move legacy files into `docs/legacy/` before applying the new pack. Nothing is deleted — review and remove `docs/legacy/` manually when you no longer need it.

## Publish

```bash
cd packages/specboot
npm publish
```

No build step. Validate manually with `node bin/init.js <tmp-dir> --pack <name>` and confirm `Errors: 0`.
