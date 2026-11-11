---
description: Backend API standards for the backend-api pack — NestJS + TypeScript + TypeORM + PostgreSQL, REST and/or GraphQL. Covers modular architecture, SOLID and dependency inversion, DTO validation, persistence and migrations, error handling, security, API contract, and testing (unit + e2e).
globs: ["src/**/*.ts", "test/**/*.ts", "package.json", "tsconfig*.json", "nest-cli.json", "docker-compose*.yml", ".env.example"]
alwaysApply: true
---

# Backend API Standards (NestJS + TypeORM)

Load together with `docs/base-standards.md`. Where this file and base standards disagree, base standards win.

**API style**: the project declares `API style: rest | graphql | both` in `docs/pack-context.md`. Sections 1–14 apply to every project (REST-specific parts of §5 and §10 only when the style includes `rest`). Section 15 applies when the style includes `graphql`.

## Table of Contents

1. [Technology Stack](#1-technology-stack)
2. [Project Structure](#2-project-structure)
3. [Architecture and SOLID](#3-architecture-and-solid)
4. [Modules, Providers and Dependency Injection](#4-modules-providers-and-dependency-injection)
5. [Controllers and DTOs](#5-controllers-and-dtos)
6. [Persistence with TypeORM](#6-persistence-with-typeorm)
7. [Error Handling](#7-error-handling)
8. [Configuration](#8-configuration)
9. [Security](#9-security)
10. [API Contract and Documentation](#10-api-contract-and-documentation)
11. [Testing (TDD)](#11-testing-tdd)
12. [Logging and Observability](#12-logging-and-observability)
13. [Tooling and Conventions](#13-tooling-and-conventions)
14. [Definition of Done](#14-definition-of-done)
15. [GraphQL (when API style includes graphql)](#15-graphql-when-api-style-includes-graphql)

---

## 1. Technology Stack

| Concern | Choice |
| --- | --- |
| Runtime | Node.js LTS (≥ 20) |
| Language | TypeScript, `strict: true` |
| Framework | NestJS (`@nestjs/core`, `@nestjs/common`, `@nestjs/platform-express`) |
| ORM | TypeORM via `@nestjs/typeorm` |
| Database | PostgreSQL (local via `docker compose`) |
| Validation | `class-validator` + `class-transformer` through the global `ValidationPipe` |
| Config | `@nestjs/config` with schema validation at boot |
| Auth | `@nestjs/jwt` + `@nestjs/passport` (`passport-jwt`), guards for authorization |
| API docs | `@nestjs/swagger` (OpenAPI 3) |
| Testing | Jest (unit), Jest + Supertest (e2e) against a real PostgreSQL |
| Lint/format | ESLint (`typescript-eslint`) + Prettier |
| Health | `@nestjs/terminus` |
| GraphQL (optional) | `@nestjs/graphql` + `@nestjs/apollo` (`@apollo/server`, `graphql`), code-first; `dataloader` for batching |

Do not introduce alternative libraries for a concern already covered above (e.g., Prisma, Joi-only validation, Mongoose) without an explicit decision recorded in the change's `design.md`.

## 2. Project Structure

Organize by **feature module**, and inside each module by **layer**. A feature never reaches into another feature's internals; it imports the other module and uses its exported providers.

```
src/
├── main.ts                      # bootstrap: global pipes, filters, versioning, Swagger, helmet, CORS
├── app.module.ts                # root module: ConfigModule, TypeOrmModule, feature modules
├── config/
│   ├── configuration.ts         # typed config factory
│   └── env.validation.ts        # env schema, fails fast at boot
├── database/
│   ├── data-source.ts           # TypeORM DataSource for the CLI (migrations)
│   └── migrations/              # generated + reviewed migration files
├── common/
│   ├── filters/                 # global exception filter(s)
│   ├── guards/                  # JwtAuthGuard, RolesGuard
│   ├── decorators/              # @Roles(), @CurrentUser()
│   ├── interceptors/
│   └── dto/                     # PaginationQueryDto, PaginatedResponseDto
└── modules/
    └── books/
        ├── books.module.ts
        ├── domain/
        │   ├── book.ts                    # domain model (no framework imports)
        │   ├── book.repository.ts         # repository interface + injection token
        │   └── errors/                    # BookNotFoundError, ...
        ├── application/
        │   └── books.service.ts           # use cases; depends on the interface, not TypeORM
        ├── infrastructure/
        │   ├── book.orm-entity.ts         # TypeORM @Entity (persistence model)
        │   ├── book.mapper.ts             # ORM entity <-> domain model
        │   └── typeorm-book.repository.ts # implements BookRepository
        └── presentation/
            ├── books.controller.ts         # REST
            ├── dto/                        # CreateBookDto, UpdateBookDto, BookResponseDto
            └── graphql/                    # only when API style includes graphql
                ├── books.resolver.ts
                ├── book.type.ts            # @ObjectType
                ├── create-book.input.ts    # @InputType
                └── book.loader.ts          # DataLoader factory
test/
├── books.e2e-spec.ts
└── jest-e2e.json
```

For very small modules (pure CRUD, no business rules) the `domain/` mapper split may be collapsed, but **the repository interface and token are always kept** — they are what makes the service unit-testable and the dependency inversion explicit.

## 3. Architecture and SOLID

Dependencies point inward: `presentation → application → domain ← infrastructure`.

- **Domain** has no imports from `@nestjs/*`, `typeorm`, or `class-validator`. It holds business rules and invariants.
- **Application** services orchestrate use cases. They depend on domain interfaces (injected by token), never on `Repository<T>` from TypeORM directly.
- **Infrastructure** implements domain interfaces with TypeORM.
- **Presentation** (controllers) translates HTTP ⇄ application calls. No business logic in controllers.

How each SOLID principle shows up in this stack:

| Principle | Rule in this pack |
| --- | --- |
| SRP | One controller per resource, one service per use-case group, one repository per aggregate. A service method does one use case. |
| OCP | Extend behavior with new providers, guards, interceptors or strategy classes; avoid `switch` on types that grows with every feature. |
| LSP | Any `BookRepository` implementation (TypeORM, in-memory for tests) must honor the same contract, including error semantics (e.g., returns `null` vs throws). |
| ISP | Keep repository and port interfaces small and use-case oriented (`findById`, `save`), not a generic 30-method interface. |
| DIP | Services depend on interfaces bound to injection tokens; the module decides the concrete class. |

Design patterns expected where they fit (name them in `design.md` when used): Repository, Mapper/Data Mapper, Strategy (interchangeable policies), Adapter (external APIs), Factory (complex aggregate creation), Decorator (Nest decorators, interceptors).

## 4. Modules, Providers and Dependency Injection

Bind interfaces to implementations with a token:

```ts
// domain/book.repository.ts
export const BOOK_REPOSITORY = Symbol('BOOK_REPOSITORY');

export interface BookRepository {
  findById(id: string): Promise<Book | null>;
  save(book: Book): Promise<Book>;
}
```

```ts
// books.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([BookOrmEntity])],
  controllers: [BooksController],
  providers: [
    BooksService,
    { provide: BOOK_REPOSITORY, useClass: TypeOrmBookRepository },
  ],
  exports: [BooksService],
})
export class BooksModule {}
```

```ts
// application/books.service.ts
@Injectable()
export class BooksService {
  constructor(@Inject(BOOK_REPOSITORY) private readonly books: BookRepository) {}
}
```

Rules:

- Constructor injection only; no `ModuleRef.get` service-locator usage in business code.
- Default (singleton) scope. Request scope only with a written justification (it cascades and costs performance).
- No circular module imports. If `forwardRef` seems necessary, the boundary is wrong — extract a shared module or an event.
- Export only what other modules need.

## 5. Controllers and DTOs

- Global `ValidationPipe` in `main.ts`:

```ts
app.useGlobalPipes(
  new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
);
```

- Every request body, query and param object has a DTO class with `class-validator` decorators. Use `ParseUUIDPipe` / `ParseIntPipe` for path params.
- Use `PartialType`, `PickType`, `OmitType` from `@nestjs/swagger` to derive update DTOs (keeps Swagger metadata).
- **Never return ORM entities** from controllers. Map to a response DTO so internal columns (password hashes, soft-delete flags) never leak.
- Status codes: `201` create, `200` read/update, `204` delete (`@HttpCode(204)`), `400` validation, `401` unauthenticated, `403` forbidden, `404` not found, `409` conflict.
- URI versioning: `app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' })` → `/v1/books`.
- Collections are paginated (`page`, `limit` with a max, e.g. 100) and return `{ data, meta: { page, limit, total } }`.
- Resource names: plural, kebab-case (`/v1/adverse-events`). JSON fields: camelCase.

## 6. Persistence with TypeORM

Connection:

```ts
TypeOrmModule.forRootAsync({
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    type: 'postgres',
    url: config.getOrThrow<string>('DATABASE_URL'),
    autoLoadEntities: true,
    synchronize: false,          // ALWAYS false; schema changes go through migrations
    migrationsRun: false,
  }),
}),
```

Entities:

- Primary keys: `@PrimaryGeneratedColumn('uuid')`.
- Audit columns: `@CreateDateColumn()`, `@UpdateDateColumn()`; soft delete with `@DeleteDateColumn()` where the domain needs it.
- Table and column names in `snake_case` (configure a naming strategy or set `name:` explicitly); class properties in camelCase.
- Declare indexes (`@Index`) for every column used in `WHERE`/`ORDER BY` of a listed query, and unique constraints at DB level, not only in code.
- Relations are **lazy by default in thinking, explicit in code**: no `eager: true`; load relations with `relations:` or a QueryBuilder join in the query that needs them. Watch for N+1.

Migrations:

- `synchronize: true` is forbidden in every environment, including local.
- A `src/database/data-source.ts` exports the `DataSource` for the TypeORM CLI. Scripts in `package.json`:
  - `migration:generate` → `typeorm-ts-node-commonjs migration:generate -d src/database/data-source.ts src/database/migrations/<Name>`
  - `migration:run` / `migration:revert`
- Every schema change in a task = one reviewed migration with a working `down()`. Never edit a migration that has been merged; add a new one.
- `docs/data-model.md` is updated in the same task as the migration.

Transactions:

- Multi-write use cases run inside one transaction (`dataSource.transaction(async (manager) => { ... })`). Repositories accept an optional `EntityManager` when they must participate in a caller's transaction.

Queries:

- Use the repository API or QueryBuilder with parameters. **Never** interpolate user input into SQL strings.
- Select only needed columns for list endpoints.

## 7. Error Handling

- Domain throws **domain errors** (plain classes extending `Error`, e.g. `BookNotFoundError`, `DuplicateIsbnError`). Domain never throws `HttpException`.
- A global exception filter maps domain errors to HTTP responses (`NotFound` → 404, `Conflict` → 409, `Validation` → 400). Unknown errors → 500 with a generic message; details go to logs only.
- Error response shape (consistent across the API):

```json
{ "statusCode": 404, "error": "Not Found", "message": "Book 3f2… not found", "path": "/v1/books/3f2…", "timestamp": "2026-01-01T00:00:00.000Z" }
```

- Translate known DB errors in the repository (PostgreSQL `23505` unique violation → `DuplicateXError`); never let raw driver errors reach the controller.

## 8. Configuration

- `ConfigModule.forRoot({ isGlobal: true, validate })` validates env vars at boot; the app fails fast on missing/invalid config.
- Read config through `ConfigService` (typed), never `process.env` scattered in code.
- Commit `.env.example` with every variable and a safe placeholder; never commit `.env`.
- Secrets (JWT secret, DB password) only from env/secret manager.

## 9. Security

- `helmet()` and an explicit CORS allow-list in `main.ts`.
- Passwords hashed with `bcrypt` or `argon2`; never logged, never returned.
- JWT: short-lived access tokens; secret from config; validate `exp`. Authorization through guards (`JwtAuthGuard`, `RolesGuard` + `@Roles()` decorator via `Reflector`), not `if` checks in services.
- Rate limiting with `@nestjs/throttler` on auth endpoints at minimum.
- Validate and whitelist all input (global `ValidationPipe` above). Limit body size.
- Sensitive or personal data: document it in `data-model.md`, minimize what is stored, mask it in logs.
- `npm audit` (or equivalent) clean of high/critical before closing a change.

## 10. API Contract and Documentation

- `@nestjs/swagger` is configured in `main.ts` and served at `/docs` (non-production or behind auth).
- Controllers and DTOs carry `@ApiTags`, `@ApiOperation`, `@ApiResponse` and `@ApiProperty` so the generated spec is complete.
- `docs/api-spec.yml` is the **reviewed contract**. In OpenSpec changes, update it in the spec phase, before implementation. After implementation, the generated Swagger document must match it (endpoints, status codes, schemas); `/verify` checks this.
- Breaking changes require a new version (`/v2`) or an explicit decision in `design.md`.

## 11. Testing (TDD)

Write the failing test first (base standards §1).

**Unit tests** (`*.spec.ts` next to the file):

- Services are tested with an **in-memory fake** or a Jest mock of the repository interface, bound by token:

```ts
const moduleRef = await Test.createTestingModule({
  providers: [BooksService, { provide: BOOK_REPOSITORY, useValue: fakeBookRepository }],
}).compile();
```

- Domain models are tested as plain classes (no Nest testing module needed).
- No database in unit tests.

**E2E tests** (`test/*.e2e-spec.ts`):

- Boot the real `AppModule` with Supertest against a real PostgreSQL (docker compose service or Testcontainers), run migrations before the suite, clean data between tests.
- Apply the same global pipes/filters as `main.ts` (extract a `configureApp(app)` function shared by `main.ts` and tests).
- Cover per endpoint: happy path, validation error (400), not found (404), auth (401/403) when protected, conflict (409) when applicable.

**Coverage**: ≥ 80% lines on `src/modules/**` (excluding DTOs, modules and ORM entities). Coverage is a floor, not a goal; assert behavior, not implementation.

Naming: `describe('BooksService')` → `it('throws BookNotFoundError when the book does not exist')`.

## 12. Logging and Observability

- Use Nest `Logger` (or `nestjs-pino` if structured JSON logs are required) with a context per class. No `console.log`.
- Log at boundaries: incoming request summary (method, path, status, duration), external calls, and errors with stack. Never log secrets, tokens or personal data.
- Expose `GET /health` with `@nestjs/terminus` (DB ping).

## 13. Tooling and Conventions

- Scripts: `start:dev`, `build`, `lint`, `format`, `test`, `test:e2e`, `test:cov`, `migration:*`.
- `docker-compose.yml` provides PostgreSQL for local dev and e2e.
- File names: kebab-case with Nest suffixes (`books.controller.ts`, `create-book.dto.ts`, `book.orm-entity.ts`). Classes PascalCase; interfaces without `I` prefix; injection tokens in `UPPER_SNAKE_CASE`.
- No `any`. Prefer `unknown` + narrowing. Explicit return types on public methods.
- Keep `main.ts` thin: delegate setup to `configureApp(app)`.
- README documents: requirements, `docker compose up -d`, env setup, migrations, run, test, and a short architecture section (diagram + patterns used).

## 14. Definition of Done

A task in this pack is done when:

- [ ] Tests written first; unit + e2e green (`npm test`, `npm run test:e2e`).
- [ ] `npm run lint` and `tsc --noEmit` clean.
- [ ] Migration generated, reviewed, reversible; `docs/data-model.md` updated.
- [ ] REST: `docs/api-spec.yml` updated and matches the generated Swagger document.
- [ ] GraphQL: `docs/schema.graphql` updated and matches the generated `src/schema.gql`; e2e covers each new query/mutation (§15.9).
- [ ] No ORM entity returned from a controller; DTOs validated.
- [ ] Errors mapped through the global filter; no raw driver errors exposed.
- [ ] No secrets in code or logs; `.env.example` updated for new variables.
- [ ] If learning mode is on (base standards §9): concepts note delivered.

## 15. GraphQL (when API style includes graphql)

GraphQL is another **presentation adapter** over the same application layer. Resolvers call the same services as controllers; no business logic, persistence or validation rules are duplicated in resolvers.

### 15.1 Setup (code-first)

Code-first: TypeScript classes with decorators are the source of the schema. Do not mix with schema-first in the same project.

```ts
GraphQLModule.forRootAsync<ApolloDriverConfig>({
  driver: ApolloDriver,
  inject: [ConfigService],
  useFactory: (config: ConfigService) => ({
    autoSchemaFile: join(process.cwd(), 'src/schema.gql'), // generated, committed
    sortSchema: true,
    path: '/graphql',
    playground: false,                                      // use Apollo Sandbox locally
    introspection: config.get('NODE_ENV') !== 'production',
    context: ({ req }) => ({ req, loaders: createLoaders(/* services */) }),
    formatError: formatGraphQLError,                        // §15.5
  }),
}),
```

### 15.2 Types and inputs

- Output types: `@ObjectType()` classes in `presentation/graphql/`, mapped from domain models. **Never expose ORM entities as GraphQL types** (same rule as REST DTOs).
- Inputs: `@InputType()` / `@ArgsType()` classes with `class-validator` decorators; the global `ValidationPipe` validates them.
- Use `ID` for identifiers (`@Field(() => ID)`), explicit `nullable` on every field that can be null, and enums registered with `registerEnumType`.
- Naming: types PascalCase (`Book`), fields camelCase, inputs suffixed `Input` (`CreateBookInput`), mutations verb-first (`createBook`, `updateBook`, `deleteBook`).

### 15.3 Resolvers

```ts
@Resolver(() => BookType)
export class BooksResolver {
  constructor(private readonly books: BooksService) {}

  @Query(() => BookType, { nullable: true })
  book(@Args('id', { type: () => ID }, ParseUUIDPipe) id: string) {
    return this.books.findById(id).then(toBookType);
  }

  @Mutation(() => BookType)
  createBook(@Args('input') input: CreateBookInput) {
    return this.books.create(input).then(toBookType);
  }

  @ResolveField(() => AuthorType)
  author(@Parent() book: BookType, @Context('loaders') loaders: Loaders) {
    return loaders.authorById.load(book.authorId);
  }
}
```

- One resolver per type. Thin: argument → service call → map to type.
- Mutations return the affected object (or a payload type) so clients can update caches.

### 15.4 N+1 and DataLoader

- Every `@ResolveField` that loads a relation goes through a **DataLoader** (`dataloader` package). Loaders are created **per request** in the GraphQL `context` factory (avoids making providers request-scoped).
- Loader batch functions call a repository method that fetches by a list of ids in one query and returns results in the same order as the keys.
- e2e or query-count tests assert that listing N items with a nested relation does not run N+1 queries.

### 15.5 Errors

- Domain errors are mapped to GraphQL errors with a stable `extensions.code` (`NOT_FOUND`, `CONFLICT`, `BAD_USER_INPUT`, `UNAUTHENTICATED`, `FORBIDDEN`) — via an exception filter for GraphQL (`GqlExceptionFilter`) or `formatError`.
- `formatError` strips stack traces and internal messages in production; unknown errors become `INTERNAL_SERVER_ERROR` with a generic message.
- Not-found on a single-item query returns `null` (field declared nullable) **or** an error with `NOT_FOUND` — choose one convention per project and record it in `design.md`.

### 15.6 Auth

- Reuse the same JWT strategy. Guards read the request from the GraphQL context:

```ts
@Injectable()
export class GqlJwtAuthGuard extends AuthGuard('jwt') {
  getRequest(context: ExecutionContext) {
    return GqlExecutionContext.create(context).getContext().req;
  }
}
```

- `RolesGuard` and `@CurrentUser()` likewise resolve the request through `GqlExecutionContext`.

### 15.7 Security and limits

- Introspection and the landing page are disabled in production.
- Limit **query depth** and **complexity** (e.g. `graphql-depth-limit`, `graphql-query-complexity`, or Apollo plugins); document the limits in `design.md`.
- Paginate every list field (max page size, same as REST). Prefer cursor-based connections (`edges`, `pageInfo`) for large or frequently changing lists; offset (`page`, `limit`) is acceptable for small admin lists. One convention per project.
- Rate limiting via `@nestjs/throttler` with a GraphQL-aware guard (override `getRequestResponse`).

### 15.8 Contract

- `docs/schema.graphql` is the **reviewed contract**: in OpenSpec changes, update it in the spec phase, before implementation.
- After implementation, the generated `src/schema.gql` must match it (`/verify` diffs both files). Breaking changes (removing fields, making a field non-nullable in inputs) require deprecation first (`@Field({ deprecationReason })`) or an explicit decision in `design.md`.
- Swagger does not cover GraphQL; when the style is `both`, keep `api-spec.yml` for REST and `schema.graphql` for GraphQL.

### 15.9 Testing

- Unit: resolvers with a faked service (`Test.createTestingModule`), loaders with a faked repository (assert one batch call for many keys).
- e2e: `POST /graphql` with Supertest against the real `AppModule`. GraphQL returns HTTP 200 even with errors, so assert on `body.data` **and** `body.errors[].extensions.code`.
- Cover per operation: happy path, validation error (`BAD_USER_INPUT`), not found, auth (`UNAUTHENTICATED` / `FORBIDDEN`) when protected, and the N+1 check for nested fields.
