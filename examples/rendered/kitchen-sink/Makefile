# Local validation targets.

.PHONY: check hooks generate

# Fitness checks (cyclomatic complexity, file/line-count limits) — the same
# gate CI runs in the `fitness` job. Run before pushing.
check:
	bash fitness_checks/run_all.sh

# Install the pre-push hook so `make check` runs automatically before each push.
hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook enabled (core.hooksPath=.githooks)"

# Regenerate the Dart API client from api/services/*.yaml, then run
# build_runner ONCE across the whole pub workspace (frontend +
# packages/shared_api_client). Mirrors the post-generation task in
# copier.yml so local dev and fresh-render codegen never drift apart.
generate:
	bash scripts/regenerate-api-client.sh
	dart run melos bootstrap
	dart run build_runner build --workspace --delete-conflicting-outputs

