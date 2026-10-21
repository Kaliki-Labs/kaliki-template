#!/usr/bin/env bash
# Preflight: verify host toolchain versions before any codegen runs. No network.
# Exits non-zero with one line per problem so a failed `copier copy` explains itself.
set -u

failures=0
fail() { echo "ERROR: $1" >&2; failures=$((failures + 1)); }
warn() { echo "WARNING: $1" >&2; }

first_version() { grep -Eo '[0-9]+(\.[0-9]+)+' | head -n1; }
# ver_ge ACTUAL MIN: success when ACTUAL >= MIN (dotted numeric versions)
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

go_min=$(awk '/^go /{print $2; exit}' backend/go.mod)
if ! command -v go >/dev/null 2>&1; then
  fail "Go not found; install Go $go_min or newer (https://go.dev/dl)"
else
  go_have=$(go env GOVERSION | first_version)
  ver_ge "$go_have" "$go_min" || fail "Go $go_have detected; backend/go.mod needs >= $go_min"
fi

node_min="20.0.0"
if ! command -v node >/dev/null 2>&1; then
  fail "Node not found; install Node $node_min or newer (api/ build needs npm)"
else
  node_have=$(node -v | first_version)
  ver_ge "$node_have" "$node_min" || fail "Node $node_have detected; api/ build needs >= $node_min"
fi

[ "$failures" -eq 0 ]
