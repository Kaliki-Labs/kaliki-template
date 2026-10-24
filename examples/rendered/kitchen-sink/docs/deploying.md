# Deploying

Target-agnostic notes on what this project expects from wherever you run it, and
traps that are easy to hit on a first real deploy. The template ships no
infrastructure code; bring your own host, registry and provisioning. `.github/workflows/publish-image.yml` builds and pushes the backend image.

## The container contract

- **Image:** `backend/Dockerfile` produces a static binary on
  `gcr.io/distroless/static-debian12:nonroot`. It runs as a non-root user with
  no shell and **no writable `$HOME`**. If you add anything that needs a cache
  or config dir (fonts, headless browsers, tooling), set its env var to a path
  you create and `chown` in the Dockerfile.
- **Config:** everything is overridable by environment variable
  (`backend/internal/config`). `backend/config/env.yaml` is dev-only and is
  excluded from the image by `backend/.dockerignore`; don't copy secrets into
  the image. Set `APP_ENV=production` and `CORS_ALLOWED_ORIGINS` (see README).
- **Migrations:** run automatically at backend startup from `/app/sql/schema`.
- **Credentials:** no static cloud keys are required. AWS clients use the default
  credential chain, so prefer an instance/task role or OIDC over long-lived
  keys.
- **Tracing:** exports are a no-op until `OTEL_EXPORTER_OTLP_ENDPOINT` (or
  `observability.endpoint`) points at a real collector.

## Pitfalls

### Keep one region everywhere
`S3_REGION` defaults to `us-east-1` in `backend/config/env.example.yaml`; change
it to your bucket's region. Region values often feed more than one client (S3, SES, an OTel X-Ray exporter,
aws-cli sidecars), so one wrong value fails in several places. Define it once
per environment and derive the rest from it.

### Container DNS on systemd-resolved hosts
When the host's `/etc/resolv.conf` points at `127.0.0.53`, Docker's embedded DNS
can fail every external lookup with
`lookup <host> on 127.0.0.11:53: server misbehaving`. Set `dns:` on the affected
service, or `{"dns": [...]}` in the Docker daemon config (which restarts every
container on that host).

### Floating image tags vs. immutable registries
Re-pushing a tag such as `<branch>-latest` is rejected by registries configured
as immutable (ECR `IMMUTABLE`). Use mutable tags for floating tags, or publish
only unique tags.

### GitHub OIDC subject claims
Repositories created after 2026-07-15 get immutable subject claims
(`repo:<org>@<org_id>/<repo>@<repo_id>:...`) instead of
`repo:<org>/<repo>:...`. A cloud trust policy written for the classic format
silently never matches (AWS: `AssumeRoleWithWebIdentity` → "Not authorized").
Check the real value under Settings → Actions → General.

### Don't auto-create buckets against real S3
Outside `us-east-1`, `CreateBucket` without a location constraint fails with
`IllegalLocationConstraintException` before it ever reports "already exists".
`internal/storage` does not create buckets. If you add that for a local store
(MinIO, RustFS), gate it on a custom `S3_ENDPOINT` being set.

## CI on Blacksmith

Workflows run on `blacksmith-4vcpu-ubuntu-2404` runners. Install the Blacksmith
GitHub App on your org first, or jobs will queue forever.

- **Dependency caches are automatic.** `actions/setup-go`, `actions/setup-node`
  and `actions/cache` are redirected to Blacksmith's colocated cache with no
  workflow change. Keep the upstream actions; do not swap in the archived
  `useblacksmith/setup-*` forks.
- **Docker service images are cached automatically** (e.g. the `postgres`
  service in the `backend` job).
- **Image builds** use `useblacksmith/setup-docker-builder` +
  `useblacksmith/build-push-action` (v2), which keep BuildKit layers on a disk
  attached to the runner instead of exporting to the GHA cache. Don't add
  `cache-from`/`cache-to`. `cache-key` is required; use one key per unrelated
  image. Multi-platform: use native `-arm` runners in a matrix, not QEMU.
- **Go build cache (dashboard toggle, not in the repo).** Enable
  *Settings -> Features -> Caching -> Go build cache* for your Blacksmith org
  (needs Go 1.24+; on by default for new orgs). Once on, it replaces the
  Go cache that `actions/setup-go` keeps; set `cache: false` on `setup-go` to
  skip the redundant download. Test-result caching is an org-wide opt-in:
  the `backend` job sets `BLACKSMITH_GOCACHEPROG_DISABLE_TEST_SHARING=1`
  because its tests hit a real Postgres.
- Optional: `useblacksmith/checkout` instead of `actions/checkout` caches the
  git checkout; only worth it for large repos.
