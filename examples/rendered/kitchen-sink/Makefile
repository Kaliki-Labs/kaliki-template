# Local validation targets.

.PHONY: check hooks arch arch-check arch-serve arch-diff arch-pr generate

# Fitness checks (cyclomatic complexity, file/line-count limits) — the same
# gate CI runs in the `fitness` job. Run before pushing.
check:
	bash fitness_checks/run_all.sh

# Install the pre-push hook so `make check` runs automatically before each push.
hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook enabled (core.hooksPath=.githooks)"

# Architecture model (go tool archmodel, pinned in backend/go.mod; policy in
# architecture.yaml). Output lands in .archmodel/ (gitignored).
ARCH_ADDR ?= 127.0.0.1:7878
BASE ?= main

# Write the Explorer: one self-contained HTML file, open it in any browser.
# REF=main makes source references links (see source.url_template).
arch:
	cd backend && go tool archmodel explore $(if $(REF),--ref $(REF))
	@echo "open .archmodel/explorer.html"

# Dependency rules, with each violation's Rationale and fix hint (also part of `make check`).
arch-check:
	cd backend && go tool archmodel check

# Live Explorer that rebuilds on change. No auth: binds to localhost by default;
# ARCH_ADDR=<tailnet-ip>:7878 to open it from another machine or a phone.
arch-serve:
	cd backend && go tool archmodel serve --addr $(ARCH_ADDR)

# Architecture diff of this branch vs BASE (default main): Markdown + image +
# diff-mode Explorer in .archmodel/.
arch-diff:
	bash scripts/arch-diff.sh $(BASE)

# Post the diff WITH its image on this branch's PR, as you (gh >= 2.99). CI
# posts only the text version: its token can't attach images.
arch-pr:
	bash scripts/arch-pr-comment.sh

# Regenerate the Dart API client from api/services/*.yaml, then run
# build_runner ONCE across the whole pub workspace (frontend +
# packages/shared_api_client). Mirrors the post-generation task in
# copier.yml so local dev and fresh-render codegen never drift apart.
generate:
	bash scripts/regenerate-api-client.sh
	dart run melos bootstrap
	dart run build_runner build --workspace --delete-conflicting-outputs
