#!/usr/bin/env bash
# Rebuild the combined OpenAPI spec, then regenerate the Dart API client
# sources (pre-build_runner: .freezed.dart/.g.dart are NOT produced here).
#
# frontend/ and packages/shared_api_client/ are members of one Dart pub
# workspace, so build_runner runs ONCE, across both packages, after this
# script (see `make generate` / copier.yml's post-generation task) — paying
# its ~11-15s builder-pipeline compile cost a single time instead of once per
# package. Run `dart run build_runner build --workspace
# --delete-conflicting-outputs` from the project root after this script to
# finish regenerating.
#
# Run after any change under api/services/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Building combined OpenAPI spec"
cd "$ROOT_DIR/api"
npm install --silent
npm run build:local

echo "==> Regenerating Dart client sources"
cd "$ROOT_DIR/packages/shared_api_client"
rm -rf lib
mkdir -p lib
dart pub get
dart run swagger_parser

echo "==> Copying hand-written overrides"
cp -r lib_custom/. lib/ 2>/dev/null || true

echo "==> Done (run 'make generate' from the project root, or"
echo "    'dart run build_runner build --workspace --delete-conflicting-outputs'"
echo "    directly, to finish regenerating generated code)"
