#!/usr/bin/env python3
from __future__ import annotations

"""sos:ship gate — reject test weakening since <base> without ledger approval.

Usage (from the repo root): test-diff-check.py <base-ref>

Findings per test file, compared as <base>...HEAD:
  deleted     the test file was removed
  skip        an added line introduces a skip/xfail/disable marker
  asserts     fewer assertion lines than before
Each finding passes only if docs/TEST-LEDGER.md (at HEAD) has a
human-approved row for that file. Exit 0 = clean, 1 = blocked, 2 = error.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sos_ledger import (  # noqa: E402  # pyright: ignore[reportMissingImports]
    DEFAULT_TEST_GLOBS,
    LEDGER_REL,
    approved_files,
    git,
    lock_patterns,
    matches,
    repo_paths,
)

SKIP_RE = re.compile(
    r"(@pytest\.mark\.(skip|xfail)|pytest\.(skip|xfail)\(|unittest\.skip|"
    r"\b(it|test|describe)\.(skip|todo)\(|\bx(it|describe|test)\(|"
    r"@Disabled\b|@Ignore\b|\bt\.Skip(Now|f)?\(|#\[ignore\]|"
    r"\bskip\s*:\s*true|\.skip\b\s*=|\bpending\b\s*\()"
)
ASSERT_RE = re.compile(
    r"(\bassert\w*\b|\bexpect\s*\(|\bshould\b|\brequire\.\w+\(|"
    r"\bXCTAssert\w*\(|\bAssert\.\w+\(|\bt\.(Error|Fatal)f?\()"
)


def file_findings(root: Path, base: str, rel: str, status: str) -> list[str]:
    if status.startswith("D"):
        return ["deleted"]
    diff = git(root, "diff", "-U0", f"{base}...HEAD", "--", rel) or ""
    added = [ln[1:] for ln in diff.splitlines() if ln.startswith("+") and not ln.startswith("+++")]
    removed = [ln[1:] for ln in diff.splitlines() if ln.startswith("-") and not ln.startswith("---")]
    found: list[str] = []
    if any(SKIP_RE.search(ln) for ln in added):
        found.append("skip")
    lost = sum(bool(ASSERT_RE.search(ln)) for ln in removed)
    gained = sum(bool(ASSERT_RE.search(ln)) for ln in added)
    if lost > gained:
        found.append(f"asserts -{lost - gained}")
    return found


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: test-diff-check.py <base-ref>", file=sys.stderr)
        return 2
    base = argv[1]
    repo = repo_paths(Path.cwd())
    if repo is None:
        print("not inside a git repository", file=sys.stderr)
        return 2
    root, git_dir = repo
    if git(root, "rev-parse", "--verify", f"{base}^{{commit}}") is None:
        print(f"unknown base ref: {base}", file=sys.stderr)
        return 2
    patterns = lock_patterns(git_dir) or DEFAULT_TEST_GLOBS
    names = git(root, "diff", "--name-status", "--no-renames", f"{base}...HEAD")
    if names is None:
        print("git diff failed", file=sys.stderr)
        return 2
    ledger = root / LEDGER_REL
    allowed = approved_files(ledger.read_text(encoding="utf-8")) if ledger.is_file() else frozenset()

    blocked: list[str] = []
    checked = 0
    for line in names.splitlines():
        status, _, rel = line.partition("\t")
        if not rel or not matches(rel, patterns):
            continue
        checked += 1
        for f in file_findings(root, base, rel, status):
            mark = "approved" if rel in allowed else "BLOCK"
            print(f"{mark:8} {rel}: {f}")
            if rel not in allowed:
                blocked.append(rel)
    if blocked:
        print(
            f"\n{len(set(blocked))} test file(s) weakened without approval. "
            f"Add a row to {LEDGER_REL} (sos:regress) and get a human to approve it."
        )
        return 1
    print(f"OK: {checked} test file(s) changed, no unapproved weakening")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
