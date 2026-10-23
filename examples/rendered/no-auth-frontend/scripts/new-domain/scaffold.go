package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func writeServiceStub(domainDir, domain string) error {
	content := fmt.Sprintf(`// Package %[1]s is a scaffolded domain stub (go -C scripts/new-domain run .).
// It compiles and can be registered, but implements no handlers yet.
package %[1]s

import (
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Service will implement this domain's gen.ServerInterface (generated from
// api/services/%[1]s.yaml) once that spec has operations. For now it holds
// just the DB pool.
type Service struct {
	pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Service { return &Service{pool: pool} }

// Register mounts this domain's routes under the given router. mw is passed
// through from internal/server/server.go — normally
// [authSvc.ScopeAuth(), rl.PerOperation(%[1]s_gen.RateLimitRule)], see the
// items domain (internal/items/service.go) for the worked pattern once it
// exists in this project, or CLAUDE.md's "Order of operations for API
// changes" section otherwise.
//
// TODO: once api/services/%[1]s.yaml defines operations, re-run
// 'go generate ./gen/api/%[1]s/...' and replace this body with
// gen.RegisterHandlersWithOptions(r, s, gen.GinServerOptions{...}) — see
// internal/items/service.go (if present) for the exact pattern.
func (s *Service) Register(r gin.IRouter, mw ...gin.HandlerFunc) {
	// No generated routes to attach to yet.
}
`, domain)
	return os.WriteFile(filepath.Join(domainDir, "service.go"), []byte(content), 0o644)
}

// writeTestSkeletons reuses, verbatim, the skeletons from the former
// scripts/new-domain.sh: TestMain connects a per-package schema, registers
// the domain on a real gin router, and setupTest truncates between tests.
func writeTestSkeletons(domainDir, domain, module string) error {
	setup := strings.NewReplacer("__DOMAIN__", domain, "__MODULE__", module).Replace(`package __DOMAIN___test

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
`)
	if err := os.WriteFile(filepath.Join(domainDir, "setup_test.go"), []byte(setup), 0o644); err != nil {
		return err
	}

	service := strings.NewReplacer("__DOMAIN__", domain, "__MODULE__", module).Replace(`package __DOMAIN___test

import "testing"

// Replace with one top-level Test<OperationId> per OpenAPI operation, with
// subtests in the order success, authorization, validation, not_found, conflict.
// Hit real endpoint paths with testsupport.DoJSON / DoJSONAuth (raw JSON string
// body in, *httptest.ResponseRecorder out) and verify DB state, not just status.
func TestPlaceholder(t *testing.T) {
	t.Skip("TODO: write service tests for __DOMAIN__")
}
`)
	return os.WriteFile(filepath.Join(domainDir, "service_test.go"), []byte(service), 0o644)
}

func writeSpecStub(specPath, domain, projectName string, authOn bool) error {
	var b strings.Builder
	fmt.Fprintf(&b, "openapi: 3.0.3\n")
	fmt.Fprintf(&b, "info:\n  title: %s — %s\n  version: 0.1.0\n", projectName, domain)
	fmt.Fprintf(&b, "paths: {}\n")
	if authOn {
		b.WriteString(`components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
`)
	}
	b.WriteString("# TODO: define this domain's operations here (then re-run\n")
	b.WriteString("# `go generate ./gen/api/" + domain + "/...` from backend/).\n")
	if authOn {
		b.WriteString("# Mark operations that need auth with `security: [{bearerAuth: []}]`,\n")
		b.WriteString("# matching the securitySchemes block above.\n")
	}
	b.WriteString("# See api/services/items.yaml (the example domain) for a complete worked\n")
	b.WriteString("# example, or CLAUDE.md's \"Order of operations for API changes\" section\n")
	b.WriteString("# if the example domain was not generated for this project.\n")
	return os.WriteFile(specPath, []byte(b.String()), 0o644)
}

func writeCodegenFiles(genDir, domain string) error {
	codegen := fmt.Sprintf(`# yaml-language-server: $schema=https://raw.githubusercontent.com/oapi-codegen/oapi-codegen/HEAD/configuration-schema.json
#
# This file is generated once by new-domain and is NOT continuously managed
# by it afterwards — hand-edit freely (e.g. to add oapi-codegen options) once
# scaffolded.
package: %[1]s_gen
generate:
  gin-server: true
  models: true
output: schema.gen.go
output-options:
  name-normalizer: ToCamelCase
  nullable-type: true
  user-templates:
    gin/gin-register.tmpl: ../_shared_templates/gin-register.tmpl
    gin/gin-wrappers.tmpl: ../_shared_templates/gin-wrappers.tmpl
`, domain)
	if err := os.WriteFile(filepath.Join(genDir, "codegen.yaml"), []byte(codegen), 0o644); err != nil {
		return err
	}

	generate := fmt.Sprintf("//go:generate go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1 --config=codegen.yaml ../../../../api/services/%[1]s.yaml\npackage %[1]s_gen\n", domain)
	return os.WriteFile(filepath.Join(genDir, "generate.go"), []byte(generate), 0o644)
}

func writeScreenStub(screenPath, domain, pascal string) error {
	content := fmt.Sprintf(`import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub screen for the %[1]s domain, scaffolded by
/// `+"`go -C scripts/new-domain run .`"+`.
///
/// Once api/services/%[1]s.yaml has operations and the API client is
/// regenerated (see TEMPLATE_NOTES.md -> "Frontend"), wire a %[2]sClient
/// provider in lib/api/rest_client_provider.dart (a commented-out stub was
/// left there at the `+"`// newdomain:providers`"+` marker) and read it from here.
// TODO(new-domain): build the real %[1]s UI.
class %[2]sScreen extends ConsumerWidget {
  const %[2]sScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('TODO: %[1]s screen'));
  }
}
`, domain, pascal)
	return os.WriteFile(screenPath, []byte(content), 0o644)
}
