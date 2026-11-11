# Backend-API Pack

For API-only services (no frontend) built with **NestJS**, exposing **REST, GraphQL, or both**.

## Stack assumed by this pack

- **Runtime / language**: Node.js LTS (≥ 20), TypeScript `strict`.
- **Framework**: NestJS, modular architecture with dependency injection.
- **Persistence**: TypeORM + PostgreSQL, migrations only (`synchronize: false`).
- **Validation**: `class-validator` / `class-transformer` via the global `ValidationPipe`.
- **Auth**: JWT with `@nestjs/jwt` + `@nestjs/passport`; guards for authorization.
- **API style**: declared in `pack-context.md` (`rest` default, `graphql`, or `both`).
- **REST docs**: `@nestjs/swagger` (OpenAPI 3), checked against `api-spec.yml`.
- **GraphQL**: `@nestjs/graphql` + Apollo, code-first, DataLoader; generated schema checked against `schema.graphql`.
- **Testing**: Jest (unit) + Supertest (e2e) against a real PostgreSQL.

## Contents

- `backend-api-standards.md` — structure, SOLID/DI, DTOs, TypeORM and migrations, errors, security, testing, Definition of Done, and GraphQL (§15).
- `api-spec.yml` — OpenAPI 3.0 example/template (REST contract).
- `schema.graphql` — GraphQL SDL example/template (GraphQL contract).
- `data-model.md` — relational data model example/template, aligned with TypeORM entities and migrations.
- `pack-context.md` — short context loaded by skills/agents when this pack is active.

## Agents bundled

- `nestjs-developer` — domain consultant for NestJS + TypeORM design and testing strategy.

## Choosing the API style

Edit the `API style:` line in `docs/pack-context.md` after installing. Delete the contract file you do not use (`api-spec.yml` for GraphQL-only, `schema.graphql` for REST-only).

## When to choose this pack

Choose `backend-api` for REST or GraphQL services without a UI in the same repository: microservices, integration APIs, backends consumed by a separate frontend or mobile app. If the repository also contains a React frontend, choose `web` instead. A FastAPI variant is on the roadmap.
