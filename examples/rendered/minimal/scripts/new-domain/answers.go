package main

import (
	"os"
	"strings"
)

// loadAnswers hand-parses .copier-answers.yml. The file is a flat `key:
// value` mapping with `#` comments (see template/.copier-answers.yml.jinja) —
// no nesting, no lists, no multi-line scalars — so a full YAML parser (and
// the dependency that would come with it) isn't needed here. Values are
// returned as their raw unquoted strings; booleans come through as the
// literal strings "true"/"false".
func loadAnswers(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	out := map[string]string{}
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		idx := strings.Index(line, ":")
		if idx < 0 {
			continue
		}
		key := strings.TrimSpace(line[:idx])
		val := strings.TrimSpace(line[idx+1:])
		val = strings.Trim(val, `"'`)
		out[key] = val
	}
	return out, nil
}
