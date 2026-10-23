#!/usr/bin/env bash
# Checks the Architecture model's dependency rules (inward-only Levels, no
# Domain -> Domain imports, nothing imports the Composition root, test-only
# modules stay out of prod code, every module has a package doc comment).
# Each failure prints the rule's Rationale and a fix hint.
#
# Policy: architecture.yaml at the project root. Tool: archmodel, pinned as a
# `tool` in backend/go.mod — no global install.

set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../backend" && pwd)"

cd "$BACKEND_DIR"
go tool archmodel check
