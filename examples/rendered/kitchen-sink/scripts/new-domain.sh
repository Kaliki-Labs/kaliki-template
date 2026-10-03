#!/usr/bin/env bash
# Scaffold backend/internal/<domain>/{setup_test.go,service_test.go} for a new
# domain. Manual helper, not a copier task. Usage:
#
#   scripts/new-domain.sh <domain>      e.g. scripts/new-domain.sh sellers
#
# The skeletons follow the items example's test wiring (see TEMPLATE_NOTES.md):
# TestMain connects a per-package schema, registers the domain on a real gin
# router, and setupTest truncates between tests. They are embedded here rather
# than copied from internal/items because users delete that example domain.
# Refuses to run if the domain directory already exists.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <domain>   (lowercase letters, digits, underscores; e.g. sellers)" >&2
  exit 2
fi
domain="$1"
if [[ ! "$domain" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "error: domain must match ^[a-z][a-z0-9_]*\$ (got '$domain')" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
dir="$BACKEND/internal/$domain"

if [ -e "$dir" ]; then
  echo "error: $dir already exists; refusing to overwrite" >&2
  exit 1
fi

module="$(sed -n 's/^module //p' "$BACKEND/go.mod")"
if [ -z "$module" ]; then
  echo "error: could not read module path from $BACKEND/go.mod" >&2
  exit 1
fi

mkdir -p "$dir"

sed -e "s|__DOMAIN__|$domain|g" -e "s|__MODULE__|$module|g" >"$dir/setup_test.go" <<'EOF'
package __DOMAIN___test

import (
	"os"
	"testing"

	"github.com/gin-gonic/gin"

	"__MODULE__/internal/__DOMAIN__"
	"__MODULE__/internal/testsupport"
)

var (
	testDB *testsupport.TestDB
	router *gin.Engine
)

func TestMain(m *testing.M) {
	testDB = testsupport.Connect("test___DOMAIN__")

	r, api := testsupport.NewRouter()
	__DOMAIN__.New(testDB.Pool).Register(api)
	router = r

	os.Exit(m.Run())
}

func setupTest(t *testing.T) {
	t.Helper()
	testDB.Truncate(t)
}
EOF

sed -e "s|__DOMAIN__|$domain|g" -e "s|__MODULE__|$module|g" >"$dir/service_test.go" <<'EOF'
package __DOMAIN___test

import "testing"

// Replace with one top-level Test<OperationId> per OpenAPI operation, with
// subtests in the order success, authorization, validation, not_found, conflict.
// Hit real endpoint paths with testsupport.DoJSON / DoJSONAuth (raw JSON string
// body in, *httptest.ResponseRecorder out) and verify DB state, not just status.
func TestPlaceholder(t *testing.T) {
	t.Skip("TODO: write service tests for __DOMAIN__")
}
EOF

echo "scaffolded $dir/{setup_test.go,service_test.go}"
echo "next: add api/services/$domain.yaml, the domain package (service.go, store.go),"
echo "      its migration, and '$domain.New(pool).Register(api)' in internal/server/server.go."
