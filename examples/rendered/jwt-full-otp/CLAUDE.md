# CLAUDE.md

Guidance for AI agents working in JWT Full OTP App.

## Stack

- `backend/` — Go HTTP server (gin + pgx). One package per domain under `internal/`.
- `api/` — OpenAPI specs; the contract is the source of truth. Update the spec first.
- `frontend/` — Flutter (Riverpod + GoRouter). Always use the Riverpod generator.

## Order of operations for API changes

1. Update `api/services/*.yaml`.
2. Implement the backend handler in `internal/<domain>`.
3. Register routes in `internal/server/server.go`.
4. Regenerate the Dart client, then build the UI.

Document every realistic 4xx a handler can return in `api/services/*.yaml`, using the shared `Error` schema for `{"error": ...}` bodies.

## Conventions

- Verify backend changes with `go test ./...`, not just `go build`.
- Migrations are goose-style files in `backend/sql/schema`, applied on startup.
- Observability is always-on with a no-op default — never gate it behind a flag.

See `TEMPLATE_NOTES.md` for how domains are wired.
