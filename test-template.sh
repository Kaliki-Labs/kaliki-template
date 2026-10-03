#!/usr/bin/env bash
# Local mirror of template-ci: render representative combos, build + test the
# backend (against a throwaway postgres), build the API spec, and analyze the
# Flutter frontend (when generated). Docker smoke-tests the default combo's full
# compose stack. Requires Go, Node, and the Flutter SDK on PATH.
#
# Unlike CI, this renders the current working tree (uncommitted changes included)
# rather than committed HEAD — so you can test edits before committing them.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
TESTPG="kaliki-template-testpg"

cleanup() {
  docker rm -f "$TESTPG" >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# Render from a clean copy of the working tree, NOT $ROOT directly: when the
# source is a git repo, copier copies the committed HEAD and ignores uncommitted
# changes. Stripping .git makes copier treat it as a plain directory, so local
# edits are tested before you commit them. (CI renders committed state — that is
# correct there, since it runs on pushed commits.)
SRC="$WORK/_src"
cp -r "$ROOT" "$SRC"
rm -rf "$SRC/.git"

echo "==> starting throwaway test postgres on :25432"
docker rm -f "$TESTPG" >/dev/null 2>&1 || true
docker run -d --name "$TESTPG" \
  -e POSTGRES_USER=test_user -e POSTGRES_PASSWORD=test_password -e POSTGRES_DB=test_db \
  -p 25432:5432 postgres:17-alpine >/dev/null
export TEST_DATABASE_URL="postgres://test_user:test_password@localhost:25432/test_db?sslmode=disable"
for i in $(seq 1 30); do
  docker exec "$TESTPG" pg_isready -U test_user >/dev/null 2>&1 && break; sleep 1
done

# name|flags
COMBOS=(
  "minimal|-d auth=none -d include_example_domain=false -d include_frontend=false"
  "default|"
  "basic|-d auth=jwt-basic"
  "token_mail|-d verification_method=token"
  "no_mailer|-d mailer=false"
  "full|-d eventing=kafka-redpanda -d payments=razorpay -d push_notifications=firebase -d object_storage=s3"
)

for combo in "${COMBOS[@]}"; do
  name="${combo%%|*}"; flags="${combo#*|}"
  echo "==> render: $name"
  uvx copier copy --defaults --trust $flags "$SRC" "$WORK/$name"

  echo "==> backend build + test: $name"
  ( cd "$WORK/$name/backend" && go build ./... && go test ./... )

  echo "==> api spec build: $name"
  ( cd "$WORK/$name/api" && npm install --silent && npm run build:local )

  if [[ -f "$WORK/$name/frontend/pubspec.yaml" ]]; then
    echo "==> frontend analyze: $name"
    ( cd "$WORK/$name/frontend" && flutter analyze )
  fi
done

if [[ "${SKIP_DOCKER:-}" != "1" ]]; then
  echo "==> docker compose up (default) + smoke"
  cd "$WORK/default"
  cp .env.example .env
  docker compose up --build -d
  for i in $(seq 1 40); do curl -fsS localhost:8080/health >/dev/null 2>&1 && break; sleep 2; done
  echo "-- health:"; curl -fsS localhost:8080/health; echo
  docker compose down -v
fi

echo "==> OK"
