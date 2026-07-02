#!/usr/bin/env python3
"""Flags non-generated Dart files in frontend/lib that exceed MAX_LINES."""

from __future__ import annotations

from pathlib import Path
import sys

MAX_LINES = 1000
TARGET_DIR = Path("frontend/lib")
IGNORED_SUFFIXES = (".g.dart", ".freezed.dart", ".gen.dart")


def is_ignored(path: Path) -> bool:
    return any(path.name.endswith(suffix) for suffix in IGNORED_SUFFIXES)


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as f:
        return sum(1 for _ in f)


def main() -> int:
    root = Path.cwd()
    target = root / TARGET_DIR
    if not target.exists():
        print(f"Target directory not found: {TARGET_DIR}", file=sys.stderr)
        return 1

    offenders: list[tuple[str, int]] = []
    for path in sorted(target.rglob("*.dart")):
        if not path.is_file() or is_ignored(path):
            continue
        line_count = count_lines(path)
        if line_count > MAX_LINES:
            offenders.append((path.relative_to(root).as_posix(), line_count))

    if not offenders:
        print(f"PASS: no non-generated Dart files in {TARGET_DIR} exceed {MAX_LINES} lines.")
        return 0

    print(f"FAIL: found {len(offenders)} non-generated Dart files in {TARGET_DIR} over {MAX_LINES} lines:")
    for path, line_count in sorted(offenders, key=lambda x: x[1], reverse=True):
        print(f"- {path}: {line_count}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
