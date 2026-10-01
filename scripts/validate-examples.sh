#!/usr/bin/env bash
# Validate the FINAL rendered build for each profile: render fresh, run copier
# _tasks (codegen, go mod tidy, flutter create, build_runner), then build + test.
# This is the real gate — it operates on a throwaway POST-TASK tree, never on the
# committed snapshot. The `validates:` list in each profile documents which of
# these steps that profile is expected to pass.
#
# Usage: scripts/validate-examples.sh [profile ...]   (default: all)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$ROOT/examples/profiles"

profiles=("$@")
if [ ${#profiles[@]} -eq 0 ]; then
  for f in "$PROFILES_DIR"/*.yml; do profiles+=("$(basename "$f" .yml)"); done
fi

has_frontend() { python3 -c "import yaml,sys; print(yaml.safe_load(open(sys.argv[1]))['answers'].get('include_frontend', False))" "$1"; }

for name in "${profiles[@]}"; do
  src="$PROFILES_DIR/$name.yml"
  work="$(mktemp -d)"
  echo "==> validating $name  ($work)"

  data_file="$(mktemp)"
  python3 -c "import yaml,sys; yaml.safe_dump(yaml.safe_load(open(sys.argv[1]))['answers'], sys.stdout, sort_keys=False)" "$src" > "$data_file"

  # Full render WITH tasks (--trust lets copier run them) — this is the post-task
  # tree we actually validate.
  copier copy --defaults --trust --data-file "$data_file" --vcs-ref HEAD "$ROOT" "$work"

  # Integration tests need the test Postgres (localhost:25432). Each render ships
  # its own compose file; bring it up per profile and always tear it down. Port
  # 25432 is fixed, so profiles run sequentially (they already do).
  compose="$work/backend/docker/docker-compose-test.yaml"
  project="validate-$name"
  # Tear down DB + workdir even if a build/test step aborts under `set -e`.
  trap '[ -f "$compose" ] && docker compose -p "$project" -f "$compose" down -v >/dev/null 2>&1; rm -rf "$work" "$data_file"' EXIT

  if [ -f "$compose" ]; then
    docker compose -p "$project" -f "$compose" up -d --wait
  fi

  ( cd "$work/backend" && go build ./... && go vet ./... && go test ./... )

  if [ "$(has_frontend "$src")" = "True" ]; then
    # copier's own _tasks already bootstrapped the frontend + shared_api_client
    # Dart pub workspace above (regenerate the API client, `flutter create`,
    # `melos bootstrap`, one `build_runner build --workspace`) — re-running
    # that here would just redo the same work for free.
    ( cd "$work/frontend" \
        && flutter analyze \
        && { ls test/*_test.dart >/dev/null 2>&1 && flutter test || echo "(no frontend tests — skipping flutter test)"; } )
  fi

  trap - EXIT
  [ -f "$compose" ] && docker compose -p "$project" -f "$compose" down -v
  rm -rf "$work" "$data_file"
  echo "==> $name OK"
done
