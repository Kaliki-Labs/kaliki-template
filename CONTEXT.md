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

**Global per-IP floor** (#26) — a baseline IP-scoped limiter applied to every route, independent of any operation's `x-rate-limit`. The code is always generated (rate-limiting infra is default-on whenever `auth != 'none'`, forcing `caching == 'redis'`), but the floor itself is gated by a runtime config flag (e.g. `RATE_LIMIT_GLOBAL_ENABLED`), **default off** — an undeclared blanket limit is a production surprise; per-operation rules are where real intent is expressed.

**Token bucket** — the rate-limiting algorithm used throughout (steady refill rate + burst allowance), as opposed to fixed-window or sliding-window-log. Chosen for compatibility with Redis GCRA implementations and to avoid fixed-window boundary bursts. No progressive/escalating lockout in the template — flat limits only; projects needing escalation implement it themselves.

**Operation identification at request time** — oapi-codegen's gin-server mode exposes no operation ID on the request context by default. The codegen templates are customized (two small template overrides: route registration and per-operation wrappers) so each generated wrapper stashes its operation ID via `c.Set(ratelimit.OperationIDKey, "{{$opid}}")`, and a generated `rateLimitRules map[string]ratelimit.Rule` (built from each operation's `x-rate-limit`) is looked up by that ID — mirroring how `BearerAuthScopes` is already stashed per-operation for auth.

**OTP attempt limiting** (#14) — a separate mechanism from the above: a Postgres `attempts INT DEFAULT 0` column with an atomic `WHERE attempts < 5` increment, scoped to a single OTP row's lifetime. Not a token bucket, not Redis-backed — a per-resource invariant, not a general rate limiter.
