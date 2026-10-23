module github.com/example/minimal-app/backend

go 1.26.3

require (
	github.com/exaring/otelpgx v0.11.1
	github.com/gin-gonic/gin v1.10.0
	github.com/google/uuid v1.6.0
	github.com/jackc/pgx/v5 v5.9.2
	github.com/pressly/goose/v3 v3.26.0
	go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin v0.67.0
	go.opentelemetry.io/otel v1.43.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.43.0
	go.opentelemetry.io/otel/sdk v1.43.0
	gopkg.in/yaml.v3 v3.0.1
)

// Architecture model, checks, queries and Explorer: `go tool archmodel ...`
// (see the `arch*` targets in the root Makefile and architecture.yaml).
require github.com/Kaliki-Labs/archmodel v0.0.0-20261023151046-9b8152991f34

tool github.com/Kaliki-Labs/archmodel/cmd/archmodel
