# Playbook: adoptar Specboot en un proyecto

Guía práctica para instalar **OpenSpec + lidr-specboot** y trabajar con desarrollo guiado por especificaciones (SDD). Cubre dos casos: un **proyecto existente** y un **proyecto desde cero**, más el flujo de cada feature.

Sale de la primera implantación real (`inverse-model`, una librería NestJS) e incluye los problemas encontrados y cómo resolverlos.

## Índice

1. [Qué se instala](#1-qué-se-instala)
2. [Requisitos](#2-requisitos)
3. [Instalación (común a los dos casos)](#3-instalación-común-a-los-dos-casos)
4. [Caso A: proyecto existente](#4-caso-a-proyecto-existente)
5. [Caso B: proyecto desde cero](#5-caso-b-proyecto-desde-cero)
6. [Flujo de una feature](#6-flujo-de-una-feature)
7. [Plantilla de `base-standards.md`](#7-plantilla-de-base-standardsmd)
8. [Checklist de instalación](#8-checklist-de-instalación)
9. [Problemas conocidos](#9-problemas-conocidos)
10. [Prompts listos para usar](#10-prompts-listos-para-usar)

---

## 1. Qué se instala

| Pieza | Qué aporta | Dónde vive |
|---|---|---|
| **OpenSpec** | El ciclo de cambios: propuesta → specs → diseño → tareas → implementación → archivo. Comandos `/opsx:*`. | `openspec/changes/` (cambios en curso), `openspec/specs/` (especificación viva), `.claude/commands/opsx/`, `.claude/skills/openspec-*` |
| **Specboot** | Las reglas del proyecto, los 5 roles de agente y las skills de apoyo. | `docs/` (estándares), `ai-specs/` (agentes y skills canónicos), `.claude/` y `.cursor/` (symlinks) |
| **Archivos de entrada** | Hacen que cada copiloto cargue las mismas reglas. | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `codex.md` → symlinks a `docs/base-standards.md` |

**Los 5 roles** (en `ai-specs/agents/`):

| Rol | Hace | Nunca |
|---|---|---|
| `orchestrator` | Descompone la historia, mantiene el plan, delega y decide el cierre | Edita código |
| `explorer` | Mapea el código, encuentra qué reutilizar | Propone soluciones |
| `architect` | Escribe `.claude/doc/<feature>/architecture.md` | Escribe código |
| `implementer` | Ejecuta una tarea con TDD siguiendo el diseño | Diseña o cierra tareas |
| `reviewer` | Valida contra spec, estándares y diseño (`verify` / `adversarial`) | Aplica correcciones |

**Idea central**: `docs/base-standards.md` es la única fuente de verdad. Todo lo que el agente construya sale de ahí, así que su calidad determina la del resultado.

## 2. Requisitos

- Node.js ≥ 20.19
- OpenSpec global: `npm install -g @fission-ai/openspec@latest`
- Este repositorio clonado en el **sistema de archivos de Linux/WSL** (no en `/mnt/c/...`), para que los symlinks funcionen:

```sh
git clone https://github.com/nrojas289/lidr-specboot.git ~/tools/lidr-specboot
```

> Si el clon termina con `error: unable to create symlink CLAUDE.md: File name too long`, ver [Problemas conocidos](#9-problemas-conocidos).

### En WSL: todo dentro de Linux

Si Node y OpenSpec están instalados en Windows, WSL los encuentra en el `PATH` (`/mnt/c/...`) y cada archivo que leen cruza la frontera Windows↔Linux: un comando que debería tardar 0,2 s tarda minutos, y `openspec config` llega a colgarse.

```sh
# 1. ¿Qué openspec se está usando? Si empieza por /mnt/c, es el de Windows.
which -a openspec node npm

# 2. Node de Linux (nvm) y OpenSpec instalado con ese npm
nvm install 24 && nvm use 24
npm install -g @fission-ai/openspec@latest
hash -r && which openspec        # debe ser una ruta de Linux (~/.npm-global/bin, ~/.nvm/...)
```

Además:

- **Proyectos y este repo en `~/`**, nunca en `/mnt/c/...` (lento y rompe los symlinks). Desde VS Code, ábrelos con la extensión *WSL* (`code .` desde la terminal de WSL).
- **Opcional**: para que Windows no vuelva a colarse en el `PATH`, añade a `/etc/wsl.conf`
  ```ini
  [interop]
  appendWindowsPath = false
  ```
  y reinicia WSL desde PowerShell con `wsl --shutdown`. Después tendrás que llamar a los ejecutables de Windows que uses desde WSL por su ruta completa, o añadirlos al `PATH` a mano (por ejemplo, la carpeta `bin` de VS Code para el comando `code`).

## 3. Instalación (común a los dos casos)

### Opción recomendada: script

```sh
~/tools/lidr-specboot/playbook/setup-specboot.sh <ruta-proyecto> --pack <web|data-science|none> [--tools claude,cursor]
```

El script es idempotente (se puede repetir) y hace, en orden:

1. Activa el **perfil ampliado de OpenSpec** (11 workflows) en la configuración global.
2. `git init` si hace falta; `openspec init --tools ...` (o `openspec update` si ya existe).
3. Ejecuta el instalador de specboot con el pack elegido.
4. Si el pack no es `web`, borra las plantillas web que el instalador copia igualmente (solo si siguen idénticas a la plantilla).
5. Copia las skills que el instalador omite: `adversarial-review`, `show-spec-working`, `sync-agent-symlinks`, con sus symlinks.
6. Crea los documentos que faltan como plantillas con `TODO(specboot)`: `openspec-tasks-mandatory-steps.md`, `pack-context.md`, `openspec/config.yaml`.
7. Comprueba que no haya symlinks rotos.

### Qué pack elegir

| Pack | Cuándo |
|---|---|
| `web` | El stack es exactamente React + Express + Prisma + PostgreSQL. Trae estándares ya escritos. |
| `data-science` | Python ≥ 3.11, pandas, scikit-learn, notebooks. |
| `none` | Cualquier otro caso (librerías, otros frameworks, CLI, móvil...). Los estándares se escriben a medida. |

### Instalación manual (si no puedes usar el script)

```sh
cd mi-proyecto
openspec init --tools claude
node ~/tools/lidr-specboot/packages/specboot/bin/init.js . --pack none
# después, a mano: pasos 1, 4, 5, 6 y 7 de la lista anterior
```

Para el perfil ampliado sin el script, edita `~/.config/openspec/config.json`:

```json
{
  "profile": "custom",
  "delivery": "both",
  "workflows": ["propose", "explore", "new", "continue", "apply", "ff", "sync", "archive", "bulk-archive", "verify", "onboard"]
}
```

y ejecuta `openspec update` en el proyecto.

---

## 4. Caso A: proyecto existente

En un proyecto existente, los estándares **se extraen del código**: el agente lee cómo está hecho y lo convierte en reglas.

### Pasos

1. **Rama de trabajo**: `git checkout -b chore/specboot`.
2. **Instalación** (sección 3).
3. **Cambiar a Opus** (`/model`) para la fase de documentación.
4. **Reescribir `docs/base-standards.md`** a partir del código, usando la [plantilla](#7-plantilla-de-base-standardsmd). Prompt sugerido: [P1](#p1-estándares-desde-un-proyecto-existente).
5. **Reescribir `docs/development_guide.md`** con los comandos reales (instalación, build, tests, Docker, CI). Lo que trae es el ejemplo LTI.
6. **Adaptar `docs/documentation-standards.md`** a la documentación real del proyecto (qué archivos se actualizan con cada tipo de cambio).
7. **Completar los `TODO(specboot)`**: `grep -rn 'TODO(specboot)' docs openspec`.
8. **Si `docs/` es un sitio publicado** (VitePress, Docusaurus, MkDocs), excluir los archivos de estándares (por ejemplo, `srcExclude` en VitePress).
9. **Limpiar referencias** a agentes o documentos que ya no existen: `grep -rn "frontend-developer\|backend-standards\|api-spec" ai-specs docs`.
10. **Revisar tú** `base-standards.md` y ajustar.
11. **Commit** y primera feature con el [flujo de una feature](#6-flujo-de-una-feature).

### Opcional: especificar el comportamiento actual

`openspec/specs/` empieza vacío. Si quieres que las features nuevas tengan contra qué compararse, crea un cambio de documentación por cada área importante (por ejemplo, `/opsx:propose document-current-auth`) cuyas specs describan el comportamiento actual, sin tareas de código, y archívalo.

---

## 5. Caso B: proyecto desde cero

Sin código del que aprender, los estándares **se deciden antes de escribir código**, y el primer cambio de OpenSpec construye el esqueleto que permite cumplirlos.

### Fase 0: instalación (10 min)

```sh
mkdir mi-proyecto
~/tools/lidr-specboot/playbook/setup-specboot.sh mi-proyecto --pack <pack>
```

### Fase 1: definir el producto (Opus)

1. Con el agente `product-strategy-analyst` o `/opsx:explore`, aterriza: qué es, para quién, alcance de la v1 y lo que queda fuera.
2. Lista corta de historias, ordenadas para que cada una entregue algo usable de extremo a extremo.
3. Guarda el resultado en `docs/product-vision.md` y añádelo al `context` de `openspec/config.yaml`.

Prompt sugerido: [P2](#p2-visión-de-producto).

### Fase 2: estándares como decisiones (Opus)

Escribe `docs/base-standards.md` con la [plantilla](#7-plantilla-de-base-standardsmd), pero como **reglas decididas**: stack y versiones, arquitectura, estilo, cómo se crea cada tipo de objeto, tests y comprobaciones obligatorias, git y documentación.

Completa también `development_guide.md` (aunque los comandos aún no existan: los creará el esqueleto), `openspec-tasks-mandatory-steps.md`, `pack-context.md` y `openspec/config.yaml`.

**Revisa este documento con detalle**: es la decisión con más impacto de todo el proyecto.

Prompt sugerido: [P3](#p3-estándares-para-un-proyecto-nuevo).

### Fase 3: el primer cambio es el esqueleto

```
/opsx:propose project-skeleton
```

No es una feature: es lo que hace verificables los estándares.

- Estructura de carpetas y configuración del lenguaje.
- Linter y formatter configurados.
- Framework de tests con un test que pasa.
- CI que ejecuta las comprobaciones obligatorias.
- `.gitignore`, Docker/compose si aplica.
- Un "hola mundo" que atraviese todas las capas.

Luego el ciclo normal: `/opsx:apply` → `/opsx:verify` → `/opsx:archive` → `/commit`.

### Fase 4: features, una por cambio

Con el [flujo de una feature](#6-flujo-de-una-feature). Cada `archive` acumula comportamiento en `openspec/specs/`: la especificación crece con el código desde el primer día.

### Fase 5: ajustar tras 1–2 features

Revisa qué reglas de `base-standards.md` estorbaron o faltaron y corrígelas. Si la corrección afecta a comportamiento ya especificado, hazla con un cambio de OpenSpec.

### Diferencias entre los dos casos

| | Proyecto existente | Proyecto desde cero |
|---|---|---|
| Estándares | Se extraen del código | Se deciden antes del código |
| `openspec/specs/` | Vacío al inicio (opcionalmente se documenta lo actual) | Crece desde el esqueleto |
| Primer cambio | Una feature real | El esqueleto y las comprobaciones |
| Riesgo principal | Estándares que no reflejan el código | Estándares que aún nadie puede verificar |

---

## 6. Flujo de una feature

```
rama → /enrich-us → /opsx:propose → revisión humana → /opsx:apply
     → /opsx:verify → adversarial-review → /opsx:archive → /commit → PR
```

| Paso | Comando | Modelo | Resultado |
|---|---|---|---|
| 1 | `git checkout -b feature/<nombre>` | | Rama aislada (o `using-git-worktrees`) |
| 2 | `/enrich-us "idea o ticket"` (opcional) | Opus | Historia con criterios de aceptación |
| 3 | `/opsx:propose <nombre>` | Opus | `openspec/changes/<nombre>/`: `proposal.md`, specs delta, `design.md`, `tasks.md` |
| 4 | **Revisión humana de los artefactos** | | El punto de control más valioso: corrige aquí el diseño, no en el código |
| 5 | `/opsx:apply` | Sonnet | Tareas implementadas una a una: architect → implementer (TDD) → reviewer |
| 6 | `/opsx:verify` | | Implementación comparada con los artefactos |
| 7 | Skill `adversarial-review` (idealmente en otra sesión) | Opus | Revisión "red team" con veredicto PASS / FAIL |
| 8 | Skill `show-spec-working` (opcional) | | Demo de la feature funcionando |
| 9 | `/opsx:archive` | | Specs delta fusionadas en `openspec/specs/`, cambio archivado |
| 10 | `/commit` | | Commits en inglés y PR |

### Variantes del paso 3

- `/opsx:new` + `/opsx:continue`: un artefacto cada vez, revisando entre medias.
- `/opsx:ff`: todos los artefactos de golpe tras `/opsx:new`.
- `/opsx:explore`: pensar una idea sin crear nada.

### Reglas que siempre aplican

- **Cambios después de `/opsx:apply`**: primero se actualizan los artefactos (specs, `tasks.md`) y después el código. Nunca "arreglos rápidos" fuera de la spec.
- **Cambios triviales** (errata, una línea de config, renombrar en un archivo): sin flujo, directamente.
- **Planificación con Opus**, implementación con Sonnet.

### Otros comandos

| Comando | Para qué |
|---|---|
| `/opsx:sync` | Fusionar specs delta sin archivar |
| `/opsx:bulk-archive` | Archivar varios cambios terminados |
| `/opsx:onboard` | Primer cambio guiado paso a paso |
| Skill `code-auditing` | Auditoría en 6 fases (seguridad, rendimiento, tipos, código muerto...) |
| Skill `sync-agent-symlinks` | Re-sincronizar symlinks tras añadir o quitar skills |
| Skill `update-docs` | Revisar qué documentación actualizar |

---

## 7. Plantilla de `base-standards.md`

Estructura usada en `inverse-model`. Las secciones 1–2 y 12–16 son genéricas de specboot; las 3–11 son específicas del proyecto.

```markdown
---
description: <qué cubre este documento>
alwaysApply: true
---

# Base Standards: <proyecto>

 1. Core Principles            — baby steps, TDD, tipos, nombres claros, reutilizar antes de escribir
 2. Language Standards         — inglés en artefactos técnicos (+ excepciones, p. ej. traducciones)
 3. Project Overview           — qué es, stack, tabla de paquetes/apps/carpetas
 4. Architecture               — responsabilidad de cada carpeta, flujo principal, reglas de dependencias
 5. Code Style                 — compilador, formatter/linter, imports, funciones vs clases, `any`
 6. Naming Conventions         — tabla: archivos, tipos, factories, tests; vocabulario del dominio
 7. Comments                   — qué se documenta y cómo
 8. Creating <Project> Objects — una subsección por tipo: opción pública, módulo, endpoint,
                                 entidad, adapter, componente, comando...: pasos y dónde registrarlo
 9. Testing                    — tipos, ubicación, helpers, cobertura mínima
10. Quality Gates              — comandos que deben pasar
11. Documentation, Releases, Git
12. Project Skills
13. Planning Model Requirement
14. Symlink Integrity
15. OpenSpec Post-Apply Changes
16. Multi-Agent Execution Model
```

La sección 8 es la que más valor aporta: convierte "cómo lo haría un senior del proyecto" en pasos que el agente sigue.

Si renumeras secciones, actualiza las referencias `base-standards.md §N` en `ai-specs/agents/*.md` y `ai-specs/skills/*/SKILL.md`:

```sh
grep -rn "base-standards.md\` §\|base-standards.md\` (§" ai-specs docs
```

---

## 8. Checklist de instalación

- [ ] `.claude/commands/opsx/` tiene 11 comandos.
- [ ] `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `codex.md` son symlinks a `docs/base-standards.md`.
- [ ] `find . -xtype l -not -path "*/node_modules/*"` no devuelve nada.
- [ ] `docs/` no contiene plantillas de otro pack (`frontend-standards.md`, `api-spec.yml`... si no es `web`).
- [ ] `base-standards.md` describe el proyecto real (stack, arquitectura, cómo se crea cada objeto, comprobaciones).
- [ ] `development_guide.md` tiene los comandos reales (ya no menciona LTI).
- [ ] `grep -rn 'TODO(specboot)' docs openspec` no devuelve nada.
- [ ] `openspec/config.yaml` lista todos los documentos de `docs/` que el agente debe leer.
- [ ] Los agentes de `ai-specs/agents/` no referencian agentes o documentos inexistentes.
- [ ] Si `docs/` es un sitio publicado, los estándares están excluidos.
- [ ] IDE reiniciado; `/opsx:propose` aparece en Claude Code.

---

## 9. Problemas conocidos

| Problema | Causa | Solución |
|---|---|---|
| `git clone` falla con `unable to create symlink CLAUDE.md: File name too long` y faltan `.claude/` y `.cursor/` | En este repo, `CLAUDE.md` está guardado como symlink, pero su contenido es un documento entero | `git reset -q` dentro del clon recupera todo lo demás. Corrección definitiva: guardar `CLAUDE.md` como archivo normal (o como symlink a `docs/base-standards.md`) |
| `--pack none` copia igualmente `frontend-standards.md`, `backend-standards.md`, `api-spec.yml`, `data-model.md` y los agentes frontend/backend | `packages/specboot/template/` los tiene fuera de `packs/` | El script los borra; corrección definitiva: moverlos a `template/docs/packs/web/` |
| Faltan `openspec-tasks-mandatory-steps.md` y `pack-context.md` (con pack `none`) | No están en la plantilla | El script crea plantillas |
| No existen `/opsx:verify`, `/opsx:ff`, `/opsx:new`... | OpenSpec usa el perfil `core` (4 comandos) | Perfil `custom` con los 11 workflows (sección 3) |
| OpenSpec muy lento en WSL; `openspec config` se cuelga | OpenSpec instalado con el npm de Windows (`/mnt/c/...` en `which openspec`) | Instalarlo con el npm de Linux (ver [En WSL](#en-wsl-todo-dentro-de-linux)). El script edita `~/.config/openspec/config.json` directamente, así que funciona igual |
| `adversarial-review`, `show-spec-working`, `sync-agent-symlinks` no se instalan | Están en `ai-specs/skills/` pero no en la plantilla | El script las copia |
| `openspec-sync-specs` duplicada | OpenSpec ya la genera | No crear symlink: `openspec update` la regenera y lo rompería |
| `development_guide.md` habla de "LTI ATS" | La plantilla es el proyecto de ejemplo | Reescribirla siempre |
| Los estándares aparecen como páginas en el sitio de docs | Specboot usa `docs/`, que también puede ser un sitio | Excluirlos (`srcExclude` en VitePress, `exclude` en Docusaurus/MkDocs) |
| `base-standards.md` pide `claude-opus-4-7` | Versión del modelo en la plantilla | Actualizar al Opus vigente en la sección "Planning Model" |
| Symlinks rotos o como archivos de texto | Repo clonado en `/mnt/c/...` o con `core.symlinks=false` | Trabajar en el sistema de archivos de WSL |

---

## 10. Prompts listos para usar

### P1. Estándares desde un proyecto existente

```
Revisa el código de este repositorio (estructura, módulos principales, patrones,
manejo de errores, tests, CI) y reescribe docs/base-standards.md con la plantilla
de playbook/README.md §7 de lidr-specboot: mantén las secciones genéricas de
specboot y escribe las específicas del proyecto (arquitectura, estilo, nombres,
cómo se crea cada tipo de objeto, tests, comprobaciones). Las reglas deben salir
del código real, no de buenas prácticas genéricas. Después adapta
development_guide.md, documentation-standards.md, pack-context.md,
openspec-tasks-mandatory-steps.md y openspec/config.yaml, y corrige las
referencias de sección en ai-specs/.
```

### P2. Visión de producto

```
Actúa como product-strategy-analyst. Quiero construir <idea>. Ayúdame a definir:
problema, usuarios, propuesta de valor, alcance de la v1, lo que queda fuera y un
backlog inicial de historias ordenadas para que cada una entregue valor de extremo
a extremo. Hazme preguntas antes de escribir. Guarda el resultado en
docs/product-vision.md.
```

### P3. Estándares para un proyecto nuevo

```
Con docs/product-vision.md como contexto, propón el stack y la arquitectura y,
cuando los apruebe, escribe docs/base-standards.md con la plantilla de
playbook/README.md §7 de lidr-specboot, como reglas decididas: estructura de
carpetas, estilo, nombres, cómo se crea cada tipo de objeto, tests, cobertura y
comprobaciones obligatorias. Después completa development_guide.md,
pack-context.md, openspec-tasks-mandatory-steps.md y openspec/config.yaml.
```

### P4. Esqueleto

```
/opsx:propose project-skeleton
Crea el esqueleto que haga cumplibles los estándares de docs/base-standards.md:
estructura, configuración, linter, framework de tests con un test, CI con las
comprobaciones obligatorias y un "hola mundo" que atraviese todas las capas.
```
