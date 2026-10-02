---
status: accepted
---

# Rate limiting is default-on infra and forces `caching == 'redis'`

We're adding rate limiting (per-operation `x-rate-limit` token buckets plus an
opt-in global per-IP floor) to the generated backend. Counters need to be
shared across instances to mean anything under horizontal scaling, and
`caching == 'redis'` is currently an optional Copier choice — so enabling
rate limiting now forces that option on, rather than falling back to
in-memory counters or building a secondary Postgres-based limiter. We decided
rate limiting should be default-on whenever `auth != 'none'` (the same tier
as OpenTelemetry: foundational, not a feature projects opt into), which means
Redis becomes a forced dependency for every generated project with auth,
not just ones that separately wanted caching.

## Considered Options

- **In-memory counters**: simplest, no new dependency, but silently wrong
  under multiple instances (each replica has its own counters) — a limiter
  that quietly stops enforcing its limit under scale is worse than one that
  fails to generate.
- **Redis-backed with silent in-memory fallback** when `caching != 'redis'`:
  rejected for the same reason — a limiter that degrades without telling
  anyone is a trap for whoever debugs it later.
- **Postgres-backed counters** (atomic `UPDATE ... WHERE`): avoids a new
  infra dependency since Postgres is always provisioned, but adds write load
  to the primary database for a high-frequency, low-value-per-row workload
  that Redis is purpose-built for.

## Consequences

Every generated project with `auth != 'none'` now provisions Redis, even if
it would otherwise have no use for caching. This is a one-way door at
generation time: a project can still disable rate limiting's *effects*
(global floor defaults off; per-operation rules are opt-in via the spec),
but removing the Redis dependency itself means regenerating or hand-editing
the project.
