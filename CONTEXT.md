# Context

## Glossary

**Rate limit scope** — the dimension a rate-limit bucket is keyed on for a given endpoint. One of:
- `ip` — client IP address. Used by the global floor (see below), opt-in per deployment.
- `identifier` — a value from the request body on a *pre-authentication* endpoint (e.g. the `email`/`phone` being logged in or verified), pointed to by an explicit key pointer in `x-rate-limit`. Distinct from `user`: there is no authenticated subject yet.
- `user` — the authenticated JWT subject. Only valid on endpoints that require `bearerAuth`.
- `custom:<name>` — a project-supplied extension point (e.g. future `workspace` scoping). Generated code calls a project-registered key-extractor function (`func(ctx) (key string, ok bool)`) for each `<name>`; the template ships the wiring but no built-in custom scopes. New `custom:<name>` scopes get a one-line glossary entry here before merging, to keep the list from sprawling unreviewed.

**`x-rate-limit`** — an OpenAPI vendor extension on an operation, declaring a token-bucket rate limit for that operation:
```yaml
x-rate-limit:
  scope: ip | identifier | user | custom:<name>
  requests: 10   # steady-state tokens per window
  window: 60s
  burst: 5       # extra capacity on top of the steady rate
```
Per-operation `x-rate-limit` rules are always active (explicit, spec-declared, reviewed in PRs) and **stack** with the global per-IP floor when that floor is enabled — they don't replace it.

**Global per-IP floor** (#26) — a baseline IP-scoped limiter applied to every route, independent of any operation's `x-rate-limit`. The code is always generated — rate limiting (and the Redis it's backed by) is unconditional infrastructure in every generated project, the same tier as Postgres and OpenTelemetry, independent of `auth`/`caching`/`include_example_domain` (there is no `caching` flag — Redis is just always there). The floor itself is gated by a runtime config flag (e.g. `RATE_LIMIT_GLOBAL_ENABLED`), **default off** — an undeclared blanket limit is a production surprise; per-operation rules are where real intent is expressed.

**Token bucket** — the rate-limiting algorithm used throughout (steady refill rate + burst allowance), as opposed to fixed-window or sliding-window-log. Chosen for compatibility with Redis GCRA implementations and to avoid fixed-window boundary bursts. No progressive/escalating lockout in the template — flat limits only; projects needing escalation implement it themselves.

**Operation identification at request time** — oapi-codegen's gin-server mode exposes no operation ID on the request context by default. The codegen templates are customized (two small template overrides: route registration and per-operation wrappers) so each generated wrapper stashes its operation ID via `c.Set(ratelimit.OperationIDKey, "{{$opid}}")`, and a generated `rateLimitRules map[string]ratelimit.Rule` (built from each operation's `x-rate-limit`) is looked up by that ID — mirroring how `BearerAuthScopes` is already stashed per-operation for auth.

**OTP attempt limiting** (#14) — a separate mechanism from the above: a Postgres `attempts INT DEFAULT 0` column with an atomic `WHERE attempts < 5` increment, scoped to a single OTP row's lifetime. Not a token bucket, not Redis-backed — a per-resource invariant, not a general rate limiter.

## Architecture tooling (#32)

**Architecture model** — a machine-readable description of a generated project's structure: its modules, the dependencies between them, and the API operations, schemas and tables each one owns. Extracted from the code, never hand-written. It is the single source that both the Explorer and the Guardrails read, so what a human sees and what an agent is held to cannot drift apart.

**Explorer** — the human-facing view of the Architecture model: navigate, drill down, and understand. Never enforces anything.

**Guardrails** — the agent-facing side of the Architecture model, made of two parts: *checks* (rules that fail with a fix hint) and *queries* (questions an agent asks the model instead of grepping, e.g. "who depends on `auth`?"). Distinct from the existing per-file fitness checks, which don't need the model.

**Module** — any unit that shows up as a node in the Architecture model. There are two kinds:
- **Domain** — a business capability treated as a vertical slice: its OpenAPI spec, backend package, tables, generated client calls and frontend feature, all under one node (e.g. `auth`, `items`).
- **Infrastructure module** — a supporting module that isn't a business capability (e.g. `ratelimit`, `mail`, `config`). Can be drilled into exactly like a Domain; it just owns no API operations of its own.

**Module card** — the summary shown for a Module at any zoom level: its purpose, public surface, what it depends on, what depends on it, and what it owns (operations, tables, events).

**Zoom level** — how far the Explorer has drilled in: system → Modules → a Module's internals → individual types/functions. Each level shows only what's relevant at that depth.

**Architecture diff** — the change a branch makes to the Architecture model compared with its base: modules, dependencies, operations and tables added or removed, plus any new rule violations. The main artifact for reviewing agent-written PRs.
