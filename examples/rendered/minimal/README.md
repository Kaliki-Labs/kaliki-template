# Minimal App

Generated from the kaliki-template stack (Go + Flutter + OpenAPI codegen, Docker-first).

## Quick start (Docker)

```sh
cp .env.example .env
docker compose up --build
curl localhost:8080/health
```

Postgres, Redis and the backend all come up together. Schema migrations run automatically on backend startup.

## Layout

- `backend/` — Go HTTP server (gin + pgx). Domains live in `internal/<domain>`.
- `api/` — OpenAPI specs (source of truth for the API contract).

## Observability

Tracing is wired in by default. Locally, both compose files start Jaeger and the
backend exports to it; browse traces at http://localhost:16686. Elsewhere the
exporter is a **no-op** until you set `observability.endpoint` in
`backend/config/env.yaml` (or `OTEL_EXPORTER_OTLP_ENDPOINT`) to a real collector.

`backend/config/env.yaml` is the live, git-ignored config; it is seeded from the
committed `backend/config/env.example.yaml` on generation. Edit the example to
change the defaults a fresh checkout starts from.

## CORS

The API enables CORS for browser clients. In development (`APP_ENV` unset or not
`production`) it reflects any `Origin`, so the frontend works with no setup. In
production set `CORS_ALLOWED_ORIGINS` to a comma-separated allowlist.

## Fitness checks

`fitness_checks/` enforces cyclomatic complexity, file/line-count limits and
the architecture rules (below), and runs in CI on every push. Run `make hooks` once per clone to enable a
local pre-push hook that runs the same checks (`make check`) before each
push; set `SKIP_CHECK=1 git push` to bypass it for a throwaway push.

## Architecture

[archmodel](https://github.com/Kaliki-Labs/archmodel), pinned in
`backend/go.mod`, extracts an Architecture model (modules, their dependencies,
the API operations, schemas and tables each owns, coupling and CRAP metrics)
and checks it against `architecture.yaml`:

```sh
make arch          # write .archmodel/explorer.html: drill-down Explorer, one offline file
make arch-serve    # live Explorer; ARCH_ADDR=<tailnet-ip>:7878 to open it from a phone
make arch-check    # dependency rules, with the why and a fix hint (part of make check)
make arch-diff     # this branch vs BASE=main: Markdown + image + diff-mode Explorer
make arch-pr       # post that diff, image included, on this branch's PR (as you, via gh)
cd backend && go tool archmodel query module auth   # JSON answers, for agents
```

Every PR gets a sticky comment with the Architecture diff as text plus Mermaid
(non-blocking; `.github/workflows/architecture-diff.yml`). CI can't attach
images, because `GITHUB_TOKEN` can't upload them, so the image comes from `make arch-pr`,
which agents run after pushing.

See `TEMPLATE_NOTES.md` for how to add a domain and remove the example.
