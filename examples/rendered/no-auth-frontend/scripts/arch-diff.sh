#!/usr/bin/env bash
# Architecture diff of the current checkout against a base ref (default: main).
# Builds both Architecture models with the SAME archmodel binary (the one pinned
# in this checkout's backend/go.mod), so a base that predates the tool still
# diffs. Used by `make arch-diff` and the architecture-diff CI workflow.
#
# Usage: scripts/arch-diff.sh [base-ref]
# Env:   ARCH_NO_IMAGE=1  skip the image (CI: it can't attach one, see
#                         scripts/arch-pr-comment.sh)
# Out:   .archmodel/{base,head}.json, diff.md, diff.json, explorer-diff.html,
#        diff.svg + diff.png (none when nothing changed; diff.md links diff.png)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
base_ref="${1:-main}"
out="$root/.archmodel"
mkdir -p "$out"
rm -f "$out"/diff.{md,json,svg,png} "$out/explorer-diff.html"

bin="$out/archmodel"
(cd "$root/backend" && go build -o "$bin" github.com/Kaliki-Labs/archmodel/cmd/archmodel)

# Diff against the merge base, like a PR does, not the tip of the base branch.
merge_base="$(git -C "$root" merge-base "$base_ref" HEAD)"
wt="$(mktemp -d)"
trap 'git -C "$root" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"' EXIT
git -C "$root" worktree add --detach --quiet "$wt" "$merge_base"

base_config="$wt/architecture.yaml"
[ -f "$base_config" ] || base_config="$root/architecture.yaml"

"$bin" build --root "$wt" --config "$base_config" --out "$out/base.json"
"$bin" build --root "$root" --out "$out/head.json"
image=(--image "$out/diff")
[ "${ARCH_NO_IMAGE:-}" = 1 ] && image=()
"$bin" diff --base "$out/base.json" --head "$out/head.json" \
  --markdown "$out/diff.md" --json "$out/diff.json" ${image[@]+"${image[@]}"}
"$bin" explore --diff --base "$out/base.json" --head "$out/head.json" \
  --out "$out/explorer-diff.html"

echo "Architecture diff vs $base_ref ($(git -C "$root" rev-parse --short "$merge_base")):"
echo "  $out/diff.md"
echo "  $out/explorer-diff.html"
