# kaliki-template

A [Copier](https://copier.readthedocs.io/) template for the Go + Flutter +
OpenAPI stack, Docker-first.

## Generate a project

### Prerequisites

Generation runs codegen and build steps on the host, so you need:

- **Go** (≥ 1.26) — backend codegen (sqlc, oapi-codegen) and `go mod tidy`.
- **Node / npm** — builds the combined OpenAPI spec.
- **Flutter SDK** (bundles Dart) — only when generating the frontend
  (`include_frontend`, the default): generates the Dart API client, scaffolds
  the platform folders (`flutter create`), and runs `build_runner`.

Pass `-d include_frontend=false` to skip the frontend (and its Flutter
requirement) entirely.

```sh
uvx copier copy gh:kaliki-tech-labs/kaliki-template my-app
# or from a local checkout:
uvx copier copy . ../my-app
```

You'll be prompted for identity (name, Go module path, bundle id, db name) and
module choices (auth, verification method, caching, eventing, payments,
push, object storage, example domain). Observability is always included with a
no-op default.

## What you get

- **Backend** — Go (gin + pgx), config-from-YAML, goose migrations on startup,
  timeouts + graceful shutdown, and one example domain.
- **Observability** — OpenTelemetry tracing via `otelgin` + `otelpgx`, no-op
  until you point `observability.endpoint` at an OTLP/gRPC collector.
- **API** — OpenAPI specs as the contract source of truth.
- **Frontend** — Flutter (Riverpod + GoRouter) with a working auth flow and
  local widgets.
- **Docker** — `docker compose up --build` brings up postgres (+redis/redpanda/
  mailpit per flags) and the backend together.

## Test the template

Needs the same toolchain as generation (Go, Node, Flutter) plus Docker.

```sh
./test-template.sh             # renders combos, go vet, docker smoke test
SKIP_DOCKER=1 ./test-template.sh   # render + go vet only (fast)
```

## Status

Working stack. Codegen pipeline, auth, Tier-2 modules, and CI are in place and
verified end-to-end (see `test-template.sh` / `.github/workflows/template-ci.yml`).

### Done
- [x] sqlc + oapi-codegen wiring (`items` is a full generated vertical slice)
- [x] redocly auto-discovery spec build + Dart client regen script
- [x] auth: JWT signup/login, email verification + password reset, argon2id,
      refresh-token rotation + revocation, and a protected `GET /auth/me`
- [x] transactional email: SMTP + SES + log transports, selected at runtime via
      `MAIL_PROVIDER`; Mailpit in the local stack; `verification_method` flag
      (OTP code vs token link). Credentials are emailed/logged, never returned
      in API responses
- [x] Tier-2 modules: caching (redis), eventing (kafka + outbox), payments,
      push, object storage — integration points, gated by flags
- [x] transactional outbox relay worker (`cmd/workers`) for eventing
- [x] frontend auth flow: secure token storage, refresh interceptor, Riverpod
      auth controller, GoRouter redirect, login/signup/home screens, local
      widgets (no shared_ui package — extract one by hand if a 2nd app needs it)
- [x] API client generated via a swagger_parser fork supporting `x-dart-type`
      (`format: date` → `LocalDate`, not `DateTime`)
- [x] goose migrations (per-file transactional), applied on startup and in tests
- [x] OpenTelemetry tracing (otelgin + otelpgx), no-op until an OTLP/gRPC
      endpoint is configured
- [x] production hardening: HTTP server timeouts + signal-based graceful
      shutdown; refuses the dev JWT secret when `APP_ENV=production`
- [x] GitHub Actions matrix (renders + builds + tests minimal/default/basic/
      token_mail/full; frontend combos also run `flutter analyze`)
- [x] integration-style handler tests for `items` + `auth` (real DB, worked
      examples in `internal/testsupport`)

### Known gaps / possible next

Ordered roughly by payoff for a fresh project.

**Operational**
- **Structured logging.** Everything uses `log.Printf` + `gin.Default()`'s text
  logger. Ship `slog` (JSON handler) with request-id propagation so logs are
  queryable and correlate with traces.
- **Metrics + real health checks.** Tracing is wired but there's no meter
  provider / `/metrics` (Prometheus). `/health` returns `ok` unconditionally —
  split into liveness (`/health`, static) vs readiness (`/ready`, pings the
  pool + redis).
- **Rate limiting / brute-force protection** on `login`/`signup`/`reset`. Redis
  is already in the default stack — a per-IP + per-account limiter middleware is
  low effort, high value.

**Correctness / DX**
- **Lint in CI.** CI builds + tests but runs no `go vet` / `golangci-lint` /
  `staticcheck` / `gofmt -l` / `sqlc vet`, and the frontend only runs
  `flutter analyze` (no `flutter test`).
- **OpenAPI request validation.** oapi-codegen generates types but the spec is
  not enforced at runtime — wire `kin-openapi` validation middleware, or accept
  that handlers validate by hand and the spec is documentation only.
- **Worked example of a protected domain route.** `auth.Middleware()` and
  `/auth/me` exist, but `items` is intentionally public — there's no reference
  for auth-gated domain CRUD (the most-copied pattern in a real app).

**Lower priority / scope calls**
- No dependency automation (Dependabot/Renovate) — generated repos drift on
  pinned Go/npm/Flutter/action versions.
- No frontend deploy story (web build target / Dockerfile); backend is fully
  containerized, the Flutter side is not.
- DB connection pool is not tunable via config (`max_conns`, timeouts).
- `distroless/static` ships CA certs but no `tzdata` — timezone-aware formatting
  is UTC-only unless `time/tzdata` is imported.
