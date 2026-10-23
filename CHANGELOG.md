# Changelog

Versions are git tags; `copier update` upgrades a generated project between them.

## Unreleased

### Added
- **Auth-free frontend (#24).** With `auth: none` the generated Flutter app no
  longer includes login/signup/OTP screens, `auth_controller`, `token_storage`,
  the auth interceptor, `authClient` or `flutter_secure_storage`; the router has
  no redirects and the shell has no sign-out. New `no-auth-frontend` example.
- **`go -C scripts/new-domain run .`** replaces the old `scripts/new-domain.sh`.
  It's now a full interactive scaffolding tool (every question also has a
  flag, for scripting/agents): it scaffolds a domain's compiling service
  stub + test skeletons, an empty `api/services/<domain>.yaml` spec stub, the
  `backend/gen/api/<domain>` oapi-codegen wiring (running `go generate` for
  you), and — via marker comments in `server.go` / `app_router.dart` /
  `rest_client_provider.dart` — auto-wires the new domain into the generated
  project. See `TEMPLATE_NOTES.md`'s "Adding a domain" section.
- **`internal/testsupport` is now unconditional infra**, generated regardless
  of `auth` / `include_example_domain`, so a domain added later by
  `new-domain` always has working test scaffolding to attach to — including
  on the `minimal` profile. Postgres pool/migrations and the `/api/v1` router
  group remain opt-in as before (gated on `auth != 'none' or
  include_example_domain`); if neither is present yet, `new-domain` detects
  this and prints the bootstrap snippet to add by hand before it can wire a
  domain in.
- **Frontend example list.** When the example domain is included, the home
  screen renders the `items` list with a read/write round-trip (`itemsClient`).
- **Frontend & API build on generation.** Post-gen tasks now build the combined
  OpenAPI spec (Node) and, for the frontend, generate the Dart API client,
  scaffold platform folders (`flutter create`), and run `build_runner` — the
  generated project is ready to `flutter run`.
- **CORS.** The API reflects any `Origin` in development (`APP_ENV != production`)
  and uses a `CORS_ALLOWED_ORIGINS` allowlist in production.
- CI now exercises `basic` and `token_mail` combos and runs `flutter analyze`;
  `test-template.sh` renders the working tree so local edits are tested
  pre-commit.

### Changed (breaking for `copier update`)
- **`frontend/` and `packages/shared_api_client/` are now one Dart pub
  workspace**, managed with [Melos](https://melos.invertase.dev). A new root
  `pubspec.yaml` declares the workspace; both packages resolve against one
  shared `.dart_tool/` and there's a single `pubspec.lock` at the project root
  instead of one per package. Post-generation codegen now runs `dart run melos
  bootstrap` + one `dart run build_runner build --workspace` instead of two
  separate `build_runner` invocations, roughly halving build_runner's
  per-render fixed compile cost. Local dev: use `make generate` after editing
  `api/services/*.yaml` (`scripts/regenerate-api-client.sh` no longer runs
  `build_runner` itself). After `copier update`, run `dart run melos
  bootstrap` once to adopt the workspace in an existing checkout.
- **OTP signup no longer starts a session** (`auth=jwt-full`, OTP method). Signup
  returns a short-lived `verification_token` (`SignupResponse`) instead of an
  access/refresh pair; the token is redeemed with the emailed code at
  `/auth/verify` to obtain the session. A new OTP screen implements the flow.
  Verification tokens cannot authenticate API calls.
- **`backend/config/env.yaml` is now generated as `env.example.yaml`** and copied
  to the git-ignored `env.yaml` on generation. After `copier update`, reconcile
  your live `env.yaml` against the new example.
- **New generation prerequisites:** Node/npm (API spec) and the Flutter SDK
  (frontend codegen). Previously only Go was required.

## v1.0.0

Initial release: Go (gin + pgx) backend, Flutter (Riverpod + GoRouter) frontend,
OpenAPI-driven codegen, auth (JWT signup/login, verification, password reset),
Tier-2 module integration points, observability, and a Docker-first stack.
