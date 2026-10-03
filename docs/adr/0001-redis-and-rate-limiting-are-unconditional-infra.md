---
status: accepted
---

# Redis and rate limiting are unconditional infra, not a flag

We're adding rate limiting (per-operation `x-rate-limit` token buckets plus an
opt-in global per-IP floor) to the generated backend. Counters need to be
shared across instances to mean anything under horizontal scaling, so the
limiter is Redis-backed, not in-memory.

Redis and rate limiting are generated in **every** project, unconditionally —
the same tier as Postgres and OpenTelemetry: foundational infra that every
generated project gets, not a feature a project opts into. This holds
regardless of `auth`, `include_example_domain`, or any other flag. There used
to be a `caching` Copier option (`none` / `redis`) that made Redis optional,
and rate limiting was wired to force that option on whenever `auth != 'none'`.
That was wrong on two counts: it left `minimal` (`auth=none`) with no rate
limiting and no Redis at all, which contradicts "always-on like
observability"; and it implied Redis's presence was *caused by* the auth
choice, when actually there is no world in which this template omits Redis.
The `caching` option has been removed entirely — there is no longer a
caching choice to force.

## Considered Options

- **In-memory counters**: simplest, no new dependency, but silently wrong
  under multiple instances (each replica has its own counters) — a limiter
  that quietly stops enforcing its limit under scale is worse than one that
  fails to generate.
- **Redis-backed with silent in-memory fallback** when Redis is unavailable:
  rejected for the same reason — a limiter that degrades without telling
  anyone is a trap for whoever debugs it later.
- **Postgres-backed counters** (atomic `UPDATE ... WHERE`): avoids a new
  infra dependency since Postgres is always provisioned, but adds write load
  to the primary database for a high-frequency, low-value-per-row workload
  that Redis is purpose-built for.

## Consequences

Every generated project provisions Redis, unconditionally — `internal/cache`,
`internal/ratelimit`, the `redis:` service in `docker-compose.yml` /
`docker-compose.services.yml`, and the `RedisConfig`/`RateLimitConfig` wiring
are all generated regardless of flags, exactly like Postgres. A project can
still disable rate limiting's *effects* (global floor defaults off;
per-operation rules are opt-in via the spec), but removing the Redis
dependency itself means hand-editing the project after generation — there is
no flag for it, the same as there is no flag to omit Postgres.
