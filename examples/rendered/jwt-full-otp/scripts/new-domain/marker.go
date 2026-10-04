package main

import (
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
)

// insertBeforeMarker looks for a line whose trimmed content exactly equals
// marker. If found, it inserts newLines (indented to match the marker line)
// directly before it and rewrites the file. If not found, it changes
// nothing and returns found=false — callers are expected to print manual
// instructions rather than guess at a fuzzy insertion point.
func insertBeforeMarker(path, marker string, newLines []string) (found bool, err error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}
	lines := strings.Split(string(data), "\n")

	idx := -1
	indent := ""
	for i, line := range lines {
		if strings.TrimSpace(line) == marker {
			idx = i
			indent = line[:len(line)-len(strings.TrimLeft(line, " \t"))]
			break
		}
	}
	if idx == -1 {
		return false, nil
	}

	out := make([]string, 0, len(lines)+len(newLines))
	out = append(out, lines[:idx]...)
	for _, l := range newLines {
		out = append(out, indent+l)
	}
	out = append(out, lines[idx:]...)

	if err := os.WriteFile(path, []byte(strings.Join(out, "\n")), 0o644); err != nil {
		return false, err
	}
	return true, nil
}

// sortImportsAroundMarker re-sorts the contiguous run of `import '...';`
// lines immediately surrounding marker (the lines directly above it, plus any
// import lines directly below it, stopping at the first blank line or
// non-import line in each direction) alphabetically by the quoted import
// path, then places marker as the last line of that run. Dart string
// comparison naturally keeps relative ("../...") imports before bare package
// imports ('.' sorts before letters), matching this project's existing
// import style without any special-casing.
func sortImportsAroundMarker(path, marker string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	lines := strings.Split(string(data), "\n")

	markerIdx := -1
	for i, line := range lines {
		if strings.TrimSpace(line) == marker {
			markerIdx = i
			break
		}
	}
	if markerIdx == -1 {
		return nil
	}

	isImport := func(s string) bool { return strings.HasPrefix(strings.TrimSpace(s), "import ") }

	start := markerIdx
	for start > 0 && isImport(lines[start-1]) {
		start--
	}
	end := markerIdx
	for end+1 < len(lines) && isImport(lines[end+1]) {
		end++
	}
	if start == markerIdx && end == markerIdx {
		return nil // no surrounding import lines to sort
	}

	var imports []string
	for i := start; i <= end; i++ {
		if i == markerIdx {
			continue
		}
		imports = append(imports, lines[i])
	}
	sort.Strings(imports)

	out := make([]string, 0, len(lines))
	out = append(out, lines[:start]...)
	out = append(out, imports...)
	out = append(out, lines[markerIdx]) // marker, pinned last in the run
	out = append(out, lines[end+1:]...)

	return os.WriteFile(path, []byte(strings.Join(out, "\n")), 0o644)
}

func manualInstructions(path, marker string, lines []string) {
	fmt.Printf("note: marker %q not found in %s; add these lines manually:\n", marker, path)
	for _, l := range lines {
		fmt.Println("  " + l)
	}
}

// serverGoHasAPIGroup reports whether server.go already declares the shared
// `pool` and `api` router group — both are conditional on auth != 'none' or
// include_example_domain at generation time (Postgres isn't unconditional
// infra; only Redis/rate-limiting is, per docs/adr/0001). The very first
// domain added to a project with neither needs that bootstrap code added by
// hand before wireServerGo's Register() call would even compile.
func serverGoHasAPIGroup(path string) (bool, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}
	return strings.Contains(string(data), `api := r.Group("/api/v1")`), nil
}

func wireServerGo(path, root, domain, module string, authOn bool) error {
	hasAPIGroup, err := serverGoHasAPIGroup(path)
	if err != nil {
		return fmt.Errorf("checking %s: %w", relPath(root, path), err)
	}
	if !hasAPIGroup {
		fmt.Printf("note: %s has no Postgres pool / \"/api/v1\" router group yet (no domain has needed one so far). Add this before wiring %s in:\n", relPath(root, path), domain)
		fmt.Println(`  poolCfg, err := pgxpool.ParseConfig(cfg.Database.URL)`)
		fmt.Println(`  ...`)
		fmt.Println(`  pool, err := pgxpool.NewWithConfig(ctx, poolCfg)`)
		fmt.Println(`  ...`)
		fmt.Println(`  api := r.Group("/api/v1")`)
		fmt.Println(`  (see internal/server/server.go.jinja's auth != 'none' or include_example_domain block in the template repo for the exact snippet, including imports and migration setup)`)
		fmt.Println("then re-run this tool to wire the import and Register() call.")
		return nil
	}

	importLines := []string{
		fmt.Sprintf(`"%s/internal/%s"`, module, domain),
		fmt.Sprintf(`%s_gen "%s/gen/api/%s"`, domain, module, domain),
	}
	found, err := insertBeforeMarker(path, "// newdomain:imports", importLines)
	if err != nil {
		return fmt.Errorf("wiring %s imports: %w", relPath(root, path), err)
	}
	if !found {
		manualInstructions(relPath(root, path), "// newdomain:imports", importLines)
	}

	authClause := ""
	if authOn {
		authClause = ", authSvc.ScopeAuth()"
	}
	registerLine := fmt.Sprintf("%s.New(pool).Register(api%s, rl.PerOperation(%s_gen.RateLimitRule))", domain, authClause, domain)
	found2, err := insertBeforeMarker(path, "// newdomain:register", []string{registerLine})
	if err != nil {
		return fmt.Errorf("wiring %s registration: %w", relPath(root, path), err)
	}
	if !found2 {
		manualInstructions(relPath(root, path), "// newdomain:register", []string{registerLine})
	}

	if found || found2 {
		if gofmtPath, err := exec.LookPath("gofmt"); err == nil {
			_ = exec.Command(gofmtPath, "-w", path).Run()
		}
		fmt.Printf("wired %s\n", relPath(root, path))
	}
	return nil
}

func wireAppRouter(path, root, domain, pascal string) error {
	importLine := fmt.Sprintf("import '../screens/%s_screen.dart';", domain)
	found, err := insertBeforeMarker(path, "// newdomain:imports", []string{importLine})
	if err != nil {
		return fmt.Errorf("wiring %s imports: %w", relPath(root, path), err)
	}
	if !found {
		manualInstructions(relPath(root, path), "// newdomain:imports", []string{importLine})
	}
	if found {
		// Dart's directives_ordering lint wants each contiguous run of
		// `import` lines alphabetical by the quoted path. Re-sort the run
		// ending at the marker so repeated new-domain runs don't drift out
		// of order (the marker line itself is pinned after the sort).
		if err := sortImportsAroundMarker(path, "// newdomain:imports"); err != nil {
			return fmt.Errorf("sorting %s imports: %w", relPath(root, path), err)
		}
	}

	routeLine := fmt.Sprintf("GoRoute(path: '/%s', builder: (_, _) => const %sScreen()),", domain, pascal)
	found2, err := insertBeforeMarker(path, "// newdomain:routes", []string{routeLine})
	if err != nil {
		return fmt.Errorf("wiring %s routes: %w", relPath(root, path), err)
	}
	if !found2 {
		manualInstructions(relPath(root, path), "// newdomain:routes", []string{routeLine})
	}

	if found || found2 {
		fmt.Printf("wired %s\n", relPath(root, path))
	}
	return nil
}

// wireRestClientProvider inserts a *commented-out* provider stub. The domain's
// api/services/<domain>.yaml is scaffolded with zero paths (see
// writeSpecStub), so the generated shared_api_client has no <Domain>Client
// class yet to reference — swagger_parser only generates a client for tags
// that have at least one operation. Wiring a live reference here would fail
// `flutter analyze` / build_runner until the spec gains real operations, so
// the stub is left commented for the next person to uncomment once it does.
func wireRestClientProvider(path, root, domain, pascal string) error {
	lines := []string{
		fmt.Sprintf("// TODO(new-domain): once api/services/%s.yaml has operations and", domain),
		"// the client is regenerated (see TEMPLATE_NOTES.md -> \"Frontend\"),",
		"// uncomment:",
		"// @riverpod",
		fmt.Sprintf("// %sClient %sClient(Ref ref) =>", pascal, domain),
		fmt.Sprintf("//     ref.watch(restClientProvider).%s;", domain),
		"",
	}
	found, err := insertBeforeMarker(path, "// newdomain:providers", lines)
	if err != nil {
		return fmt.Errorf("wiring %s: %w", relPath(root, path), err)
	}
	if !found {
		manualInstructions(relPath(root, path), "// newdomain:providers", lines)
		return nil
	}
	fmt.Printf("wired %s (commented stub — see TODO)\n", relPath(root, path))
	return nil
}
