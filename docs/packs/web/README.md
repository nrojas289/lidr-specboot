# Web Pack

Default pack for full-stack web applications (frontend + backend REST API).

## Stack assumed by this pack

- **Frontend**: React + TypeScript, React Router, React Bootstrap, Cypress (E2E).
- **Backend**: Node.js + Express + TypeScript, Prisma ORM, PostgreSQL, Jest.
- **API contract**: OpenAPI 3.0 (`api-spec.yml`).
- **Data model**: relational, documented in `data-model.md`.

## Contents

- `frontend-standards.md` — React components, UI/UX guidelines, frontend architecture.
- `backend-standards.md` — API development, database patterns, testing, security.
- `api-spec.yml` — OpenAPI 3.0 example/template.
- `data-model.md` — relational data model example/template.
- `pack-context.md` — short context loaded by skills/agents when this pack is active.

## Agents bundled

- `frontend-developer`
- `backend-developer`

## When to choose this pack

Choose `web` when building a customer-facing application with a UI and a REST backend. For pure API services without frontend, prefer the upcoming `backend-api` pack. For landing pages and static sites, this pack also applies; skip the backend standards when irrelevant.
