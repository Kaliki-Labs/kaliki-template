// Command server runs the HTTP API: it loads config, applies migrations and
// serves the routes wired up in internal/server.
package main

import "github.com/example/kitchen-sink-app/backend/internal/server"

func main() {
	server.Run()
}
