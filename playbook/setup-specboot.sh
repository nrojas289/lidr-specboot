#!/usr/bin/env bash
# Instala OpenSpec + lidr-specboot en un proyecto y corrige los huecos
# conocidos del instalador (ver playbook/README.md, "Problemas conocidos").
#
#   playbook/setup-specboot.sh <directorio-proyecto> --pack <web|data-science|none> [--tools claude,cursor]
#
# Es idempotente: nunca sobrescribe archivos existentes y solo borra
# archivos que siguen idénticos a la plantilla.
set -euo pipefail

SPECBOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$SPECBOOT_DIR/packages/specboot/template"
EXTRA_SKILLS=(adversarial-review show-spec-working sync-agent-symlinks)
WEB_DOCS=(frontend-standards.md backend-standards.md api-spec.yml data-model.md)
WEB_AGENTS=(frontend-developer.md backend-developer.md)
ALL_WORKFLOWS='["propose","explore","new","continue","apply","ff","sync","archive","bulk-archive","verify","onboard"]'

TARGET=""
PACK=""
TOOLS="claude"

usage() {
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack) PACK="${2:-}"; shift 2 ;;
    --pack=*) PACK="${1#*=}"; shift ;;
    --tools) TOOLS="${2:-}"; shift 2 ;;
    --tools=*) TOOLS="${1#*=}"; shift ;;
    -h|--help) usage 0 ;;
    *) [[ -z "$TARGET" ]] && TARGET="$1" || usage 2; shift ;;
  esac
done

[[ -n "$TARGET" && -n "$PACK" ]] || usage 2
case "$PACK" in web|data-science|none) ;; *) echo "Pack desconocido: $PACK" >&2; exit 2 ;; esac

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

# --- Requisitos -------------------------------------------------------------
step "Comprobando requisitos"
command -v node >/dev/null || { echo "Falta Node.js (>= 20.19)" >&2; exit 1; }
command -v openspec >/dev/null || { echo "Falta OpenSpec: npm install -g @fission-ai/openspec@latest" >&2; exit 1; }
[[ -f "$TEMPLATE_DIR/../bin/init.js" ]] || { echo "No encuentro el instalador en $SPECBOOT_DIR" >&2; exit 1; }
note "node $(node --version), openspec en $(command -v openspec)"
if [[ "$(command -v openspec)" == /mnt/* ]]; then
  note "AVISO: openspec es el de Windows y será muy lento en WSL."
  note "       Instálalo con el npm de Linux: npm install -g @fission-ai/openspec@latest"
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
export OPENSPEC_TELEMETRY=0

# --- Perfil ampliado de OpenSpec (global) -----------------------------------
# `openspec config profile` es un selector interactivo, así que se edita el
# archivo de configuración global directamente.
step "Perfil de OpenSpec con todos los workflows"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/openspec/config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"
node -e '
  const fs = require("fs");
  const [file, workflows] = process.argv.slice(1);
  const config = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
  const all = JSON.parse(workflows);
  const same = config.profile === "custom" &&
    JSON.stringify(config.workflows ?? []) === JSON.stringify(all);
  if (same) { console.log("    ya configurado"); process.exit(0); }
  Object.assign(config, { profile: "custom", delivery: config.delivery ?? "both", workflows: all });
  fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n");
  console.log("    perfil custom guardado en " + file);
' "$CONFIG_FILE" "$ALL_WORKFLOWS"

# --- OpenSpec ---------------------------------------------------------------
cd "$TARGET"
[[ -d .git ]] || { step "git init"; git init -q; }

if [[ -d openspec ]]; then
  step "OpenSpec ya inicializado: openspec update"
  openspec update </dev/null
else
  step "openspec init --tools $TOOLS"
  openspec init --tools "$TOOLS" </dev/null
fi

# --- Specboot ---------------------------------------------------------------
step "Instalador de specboot (pack: $PACK)"
node "$TEMPLATE_DIR/../bin/init.js" . --pack "$PACK" </dev/null

# --- Limpieza de plantillas web cuando el pack no es web ---------------------
# La plantilla trae archivos web fuera de packs/, así que se copian con
# cualquier pack. Solo se borran si siguen idénticos a la plantilla.
if [[ "$PACK" != web ]]; then
  step "Quitando plantillas web que no aplican al pack $PACK"
  for file in "${WEB_DOCS[@]}"; do
    if [[ -f "docs/$file" ]] && cmp -s "docs/$file" "$TEMPLATE_DIR/docs/$file"; then
      rm "docs/$file"; note "borrado docs/$file"
    fi
  done
  for agent in "${WEB_AGENTS[@]}"; do
    if [[ -f "ai-specs/agents/$agent" ]] && cmp -s "ai-specs/agents/$agent" "$TEMPLATE_DIR/ai-specs/agents/$agent"; then
      rm "ai-specs/agents/$agent"; note "borrado ai-specs/agents/$agent"
      for tool in .claude .cursor; do
        [[ -L "$tool/agents/$agent" ]] && rm "$tool/agents/$agent" && note "borrado $tool/agents/$agent"
      done
    fi
  done
fi

# --- Skills que el instalador no copia ---------------------------------------
step "Skills adicionales: ${EXTRA_SKILLS[*]}"
for skill in "${EXTRA_SKILLS[@]}"; do
  if [[ ! -e "ai-specs/skills/$skill" ]]; then
    cp -r "$SPECBOOT_DIR/ai-specs/skills/$skill" "ai-specs/skills/$skill"
    note "copiada ai-specs/skills/$skill"
  fi
  for tool in .claude .cursor; do
    if [[ ! -e "$tool/skills/$skill" && ! -L "$tool/skills/$skill" ]]; then
      mkdir -p "$tool/skills"
      ln -s "../../ai-specs/skills/$skill" "$tool/skills/$skill"
      note "symlink $tool/skills/$skill"
    fi
  done
done

# --- Documentos que faltan en la plantilla -----------------------------------
step "Documentos base que faltan"
if [[ ! -f docs/openspec-tasks-mandatory-steps.md ]]; then
  if [[ "$PACK" == web ]]; then
    cp "$SPECBOOT_DIR/docs/openspec-tasks-mandatory-steps.md" docs/
    note "copiado docs/openspec-tasks-mandatory-steps.md (versión web)"
  else
    cat > docs/openspec-tasks-mandatory-steps.md <<'EOF'
# OpenSpec Tasks: Mandatory Steps

Checklist for creating or updating any OpenSpec `tasks.md` in this project. A `tasks.md` is incomplete if a section below is missing, or is omitted without a written reason.

<!-- TODO(specboot): adapt every step to this project's stack and gates. -->

## Always

1. **Feature branch**: first task creates `feature/<change-name>`.
2. **Blueprint first**: a task for `architect` to produce `.claude/doc/<feature>/architecture.md` before any implementation task (`base-standards.md`, multi-agent section).
3. **Tests first**: each implementation task is preceded by (or includes) its failing test.
4. **Project-specific checks**: TODO (e.g. every supported database, security review, migrations).
5. **Documentation**: update the docs affected by the change.
6. **Quality gates**: TODO (build, lint, test commands).
7. **Verification**: a final task to run `/opsx:verify` (and the `adversarial-review` skill for risky changes) before archive.

## Rules

- Changes after `/opsx:apply` update the OpenSpec artifacts first; never add "bugfix" tasks at the end.
- Tasks are small (one reviewable step each) and ordered by build sequence.
EOF
    note "creado docs/openspec-tasks-mandatory-steps.md (plantilla por completar)"
  fi
fi

if [[ ! -f docs/pack-context.md ]]; then
  cat > docs/pack-context.md <<'EOF'
# Pack Context

<!-- TODO(specboot): describe how a user story maps to work in this project. -->

Active pack: **custom**.

- A user story maps to: TODO.
- `tasks.md` should include: TODO (see `openspec-tasks-mandatory-steps.md`).
- `/opsx:verify` checks: TODO (quality gates).

Standards to load alongside `base-standards.md`:

- `docs/documentation-standards.md`
- `docs/openspec-tasks-mandatory-steps.md`
EOF
  note "creado docs/pack-context.md (plantilla por completar)"
fi

if [[ ! -f openspec/config.yaml ]]; then
  cat > openspec/config.yaml <<'EOF'
schema: spec-driven

# TODO(specboot): describe the project and keep this list in sync with docs/.
context: |
  Project: TODO one paragraph: what it is, stack, main modules.

  Always read before proposing or implementing:
  - docs/base-standards.md
  - docs/pack-context.md
  - docs/documentation-standards.md
  - docs/openspec-tasks-mandatory-steps.md
  - docs/development_guide.md

  Skills and role agents live in ai-specs/ (canonical); .claude/ and .cursor/
  hold symlinks. English only in code, docs and commits.

rules:
  tasks:
    - Follow docs/openspec-tasks-mandatory-steps.md.
    - Tests come first.
  specs:
    - Describe observable behaviour.
EOF
  note "creado openspec/config.yaml (plantilla por completar)"
fi

# --- Verificación -------------------------------------------------------------
step "Verificando symlinks"
broken="$(find . -xtype l -not -path '*/node_modules/*' 2>/dev/null || true)"
if [[ -n "$broken" ]]; then
  echo "    Symlinks rotos:"; echo "$broken" | sed 's/^/      /'
else
  note "sin symlinks rotos"
fi

step "Listo. Pendiente (ver playbook/README.md):"
note "1. Reescribir docs/base-standards.md con las reglas reales del proyecto (Opus)."
note "2. Adaptar development_guide.md y documentation-standards.md (traen el ejemplo LTI)."
note "3. Completar los TODO(specboot): grep -rn 'TODO(specboot)' docs openspec"
note "4. Si docs/ es un sitio publicado (VitePress, Docusaurus...), excluir estos archivos."
note "5. Reiniciar el IDE para cargar los comandos /opsx:*."
