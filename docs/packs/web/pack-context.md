# Pack Context: web

Active pack: **web**.

Skills and agents must interpret OpenSpec user stories as **product features** delivered through a UI and/or REST API.

- A user story typically maps to a UI flow + one or more REST endpoints.
- `tasks.md` should include: API contract update (`api-spec.yml`), data model change (`data-model.md`), backend implementation + tests, frontend implementation + tests, E2E happy-path.
- Verification (`/verify`) checks: tests green, OpenAPI contract honored, UI flow renders expected states.

Standards to load alongside `base-standards.md`:

- `docs/frontend-standards.md`
- `docs/backend-standards.md`
