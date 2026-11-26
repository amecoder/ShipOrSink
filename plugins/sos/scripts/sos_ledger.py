from __future__ import annotations

"""Shared helpers: TEST-LEDGER.md parsing, test-lock patterns, repo discovery.

The ledger is a Markdown table. A row is "approved" only when both
`approved_by` and `approved_at` are filled. Those two columns are written by a
human; the test-lock hook refuses edits by the agent that would add them.
"""

import fnmatch
import subprocess
from dataclasses import dataclass
from pathlib import Path

LEDGER_REL = "docs/TEST-LEDGER.md"
LOCK_REL = "sos/test-lock"  # relative to the absolute git dir
EMPTY_CELLS = frozenset({"", "-", "—"})
DEFAULT_TEST_GLOBS = (
    "tests/*",
    "test/*",
    "__tests__/*",
    "*_test.*",
    "*_tests.*",
    "test_*.*",
    "*.test.*",
    "*.spec.*",
    "*Test.java",
    "*Test.kt",
    "*Tests.swift",
    "*Tests.cs",
    "*_spec.rb",
)


@dataclass(frozen=True)
class LedgerRow:
    """One ledger table row keyed by header names."""

    cells: tuple[tuple[str, str], ...]

    def get(self, key: str) -> str:
        """Return the cell value for header `key` ('' when absent)."""
        for k, v in self.cells:
            if k == key:
                return v
        return ""

    @property
    def approved(self) -> bool:
        """True when a human filled both approval columns."""
        return (
            self.get("approved_by") not in EMPTY_CELLS
            and self.get("approved_at") not in EMPTY_CELLS
        )


def _split_row(line: str) -> list[str]:
    inner = line.strip()
    if inner.startswith("|"):
        inner = inner[1:]
    if inner.endswith("|"):
        inner = inner[:-1]
    return [c.strip() for c in inner.split("|")]


def parse_ledger(text: str) -> tuple[LedgerRow, ...]:
    """Parse every table whose header has `test_id` and `file` columns."""
    rows: list[LedgerRow] = []
    header: list[str] | None = None
    for line in text.splitlines():
        if not line.strip().startswith("|"):
            header = None
            continue
        cells = _split_row(line)
        if header is None:
            if "test_id" in cells and "file" in cells:
                header = cells
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue  # separator row
        rows.append(LedgerRow(tuple(zip(header, cells))))
    return tuple(rows)


def approved_files(text: str) -> frozenset[str]:
    """Files that have at least one human-approved ledger row."""
    return frozenset(r.get("file") for r in parse_ledger(text) if r.approved)


def approved_row_keys(text: str) -> frozenset[tuple[str, ...]]:
    """Identity of approved rows, used to detect newly added approvals."""
    return frozenset(
        tuple(v for _, v in r.cells) for r in parse_ledger(text) if r.approved
    )


def git(cwd: Path, *args: str) -> str | None:
    """Run git and return stripped stdout, or None on failure."""
    try:
        out = subprocess.run(
            ("git", "-C", str(cwd), *args),
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.stdout.strip()


def repo_paths(cwd: Path) -> tuple[Path, Path] | None:
    """Return (work tree root, absolute git dir) for `cwd`, or None."""
    top = git(cwd, "rev-parse", "--show-toplevel")
    gdir = git(cwd, "rev-parse", "--absolute-git-dir")
    if not top or not gdir:
        return None
    return Path(top), Path(gdir)


def lock_patterns(git_dir: Path) -> tuple[str, ...] | None:
    """Patterns from the lock file, or None when no lock is active."""
    lock = git_dir / LOCK_REL
    if not lock.is_file():
        return None
    lines = (ln.strip() for ln in lock.read_text(encoding="utf-8").splitlines())
    return tuple(ln for ln in lines if ln and not ln.startswith("#"))


def matches(rel: str, patterns: tuple[str, ...]) -> bool:
    """True if repo-relative path `rel` falls under any pattern.

    `dir/` matches everything below dir; other patterns are fnmatch globs
    tried against the full path and the basename.
    """
    name = rel.rsplit("/", 1)[-1]
    for p in patterns:
        if p.endswith("/"):
            if rel.startswith(p):
                return True
        elif fnmatch.fnmatch(rel, p) or fnmatch.fnmatch(name, p):
            return True
    return False


def relative(path: str, root: Path) -> str | None:
    """Repo-relative POSIX path for `path`, or None when outside the repo."""
    p = Path(path)
    if not p.is_absolute():
        p = root / p
    try:
        return p.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return None
