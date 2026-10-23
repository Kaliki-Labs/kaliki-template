---
status: accepted
---

# Architecture tooling is a pinned external tool, not template code

The Architecture model, Explorer and Guardrails (#32) live in a separate repo,
[Kaliki-Labs/archmodel](https://github.com/Kaliki-Labs/archmodel). Generated
projects pin it with a `tool` directive in `backend/go.mod` and run it as
`go tool archmodel …`. The template ships only the project-specific parts:
`architecture.yaml` (conventions, levels, rule rationales), the `make arch*`
targets, the CLAUDE.md guidance and the PR-comment workflow. It is always
generated, with no Copier flag.

Copier copies; it doesn't link. If the tool were template code, every
generated project would carry a frozen copy of an extractor, a check engine and
a vendored JS graph library. Fixes would have to reach projects through
`copier update` merges, and the project's own fitness checks, linters and
agents would treat the tool as project code. As a pinned tool, a fix is a
version bump. Keeping all conventions in `architecture.yaml` also stops the
tool from quietly coming to assume template internals.

## Considered Options

- **Template code under `scripts/arch`** (like `scripts/new-domain`): rejected for the reasons above. `new-domain` is small and one-shot; this is a large tool that keeps changing.
- **A separate module inside this repo (`tools/arch/`)**: avoids a second repo, but blurs the boundary that the split is meant to enforce.

## Consequences

Two repos to keep in step. Template CI runs the pinned tool against
`examples/rendered/*` so that breakage on either side shows up quickly.
