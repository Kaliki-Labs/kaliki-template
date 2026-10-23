#!/usr/bin/env bash
# Posts the Architecture diff WITH its image on the current branch's PR. CI
# posts the text-only diff (GITHUB_TOKEN can't upload attachments); this runs
# as you, through your `gh` login (gh >= 2.99), so `--attach` works. Replaces
# your previous image comment, so re-run it after pushing new changes.
#
# Usage: scripts/arch-pr-comment.sh      (or `make arch-pr`)
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

read -r pr base < <(gh pr view --json number,baseRefName --jq '"\(.number) \(.baseRefName)"')
git fetch --quiet origin "$base"
bash scripts/arch-diff.sh "origin/$base"

if [ ! -f .archmodel/diff.png ]; then
  echo "No architecture changes vs $base: nothing to post."
  exit 0
fi

# Remove this user's earlier image comments (CI's sticky comment is the bot's,
# so it is untouched). `--edit-last` isn't used: it can't attach and may edit
# an unrelated comment.
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
me="$(gh api user --jq .login)"
gh api --paginate "repos/$repo/issues/$pr/comments" \
  --jq ".[] | select(.user.login == \"$me\" and (.body | startswith(\"<!-- archmodel-diff -->\"))) | .id" |
  while read -r id; do gh api -X DELETE "repos/$repo/issues/comments/$id" >/dev/null; done

# gh uploads diff.png and rewrites diff.md's ![...](diff.png) to the asset.
(cd .archmodel && gh pr comment "$pr" --body-file diff.md --attach diff.png)
