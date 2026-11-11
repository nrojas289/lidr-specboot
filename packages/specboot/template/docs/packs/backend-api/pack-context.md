# Pack Context: backend-api

Active pack: **backend-api** (NestJS + TypeORM + PostgreSQL, no frontend).

API style: rest   <!-- edit: rest | graphql | both -->

Skills and agents must interpret OpenSpec user stories as **API capabilities** consumed by other systems or clients, not UI flows.

- A user story typically maps to one or more endpoints plus the business rules behind them.
- `tasks.md` should include, in order: API contract update (`docs/api-spec.yml` for REST, `docs/schema.graphql` for GraphQL), data model + migration (`docs/data-model.md`), domain model and errors with unit tests, application service with unit tests (repository faked by token), TypeORM repository, controller + DTOs and/or resolver + GraphQL types/inputs (+ DataLoader for nested relations), e2e tests per endpoint or operation (happy path + error cases), Swagger annotations (REST).
- Acceptance criteria are expressed as **API behavior**: for REST, method, path, request, status code, response shape and error cases; for GraphQL, the operation document, variables, `data` shape and `errors[].extensions.code`.
- Verification (`/verify`) checks: unit + e2e green, lint + `tsc --noEmit` clean, migration reversible, generated Swagger matches `docs/api-spec.yml` (REST) and generated `src/schema.gql` matches `docs/schema.graphql` (GraphQL), Definition of Done in `docs/backend-api-standards.md` §14 satisfied.

Standards to load alongside `base-standards.md`:

- `docs/backend-api-standards.md`
- `docs/api-spec.yml` (REST contract)
- `docs/schema.graphql` (GraphQL contract)
- `docs/data-model.md` (schema)

Agents available:

- `nestjs-developer` — domain consultant for NestJS module design, DI, TypeORM persistence and migrations, DTO validation, guards, GraphQL resolvers and DataLoader, and testing strategy. Plans only; never implements.
