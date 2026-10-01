# Local validation targets.

.PHONY: check hooks

# Fitness checks (cyclomatic complexity, file/line-count limits) — the same
# gate CI runs in the `fitness` job. Run before pushing.
check:
	bash fitness_checks/run_all.sh

# Install the pre-push hook so `make check` runs automatically before each push.
hooks:
	git config core.hooksPath .githooks
	@echo "pre-push hook enabled (core.hooksPath=.githooks)"
