#!/usr/bin/env python3
from __future__ import annotations

"""PreToolUse hook: keep locked tests read-only during sos:build / sos:done.

Lock file: <git dir>/sos/test-lock (one pattern per line, `dir/` or glob).
- No lock -> allow everything (exit 0).
- Locked test file edits (Edit/Write/MultiEdit/NotebookEdit or a mutating
  Bash command naming it) -> exit 2, unless docs/TEST-LEDGER.md has a
  human-approved row for that file.
- Any agent edit that adds an approved row to the ledger -> exit 2.
  Approval columns are filled by a human outside the agent.
Unparseable input or a cwd outside git passes (nothing to protect).
"""

import json
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from sos_ledger import (  # noqa: E402  # pyright: ignore[reportMissingImports]
    LEDGER_REL,
    approved_files,
    approved_row_keys,
    lock_patterns,
    matches,
    relative,
    repo_paths,
)

FILE_TOOLS = frozenset({"Edit", "Write", "MultiEdit", "NotebookEdit"})
MUTATING_WORDS = frozenset(
    {"rm", "mv", "cp", "truncate", "tee", "dd", "install", "unlink", "shred"}
)
INPLACE_FLAGS = ("-i", "--in-place")
INPLACE_TOOLS = frozenset({"sed", "perl", "gsed", "ruby"})
GIT_MUTATING = frozenset({"rm", "mv", "checkout", "restore", "apply"})
REDIRECTS = (">", ">>", "1>", "2>", "&>")


def block(msg: str) -> None:
    print(f"[sos test-lock] {msg}", file=sys.stderr)
    sys.exit(2)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def new_content(tool: str, inp: dict, current: str) -> str:
    """Content of the file after the tool runs."""
    if tool == "Write":
        return str(inp.get("content", ""))
    edits = inp.get("edits") if tool == "MultiEdit" else [inp]
    text = current
    for e in edits or []:
        old, new = str(e.get("old_string", "")), str(e.get("new_string", ""))
        if e.get("replace_all"):
            text = text.replace(old, new)
        else:
            text = text.replace(old, new, 1)
    return text


def check_ledger_edit(tool: str, inp: dict, ledger: Path) -> None:
    current = read_text(ledger)
    after = new_content(tool, inp, current)
    if approved_row_keys(after) - approved_row_keys(current):
        block(
            "TEST-LEDGER.md 의 approved_by·approved_at 칸은 사람이 채운다. "
            "승인 칸을 비운 채로 줄을 추가하고 사람에게 승인을 요청해."
        )


def bash_targets(command: str, root: Path) -> tuple[bool, list[str]]:
    """(is_mutating, repo-relative path tokens) for a Bash command."""
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        tokens = command.split()
    words = [t.rsplit("/", 1)[-1] for t in tokens]
    mutating = any(w in MUTATING_WORDS for w in words)
    mutating |= any(
        w in INPLACE_TOOLS and any(f.startswith(INPLACE_FLAGS) for f in tokens)
        for w in words
    )
    if "git" in words:
        i = words.index("git")
        mutating |= any(w in GIT_MUTATING for w in words[i + 1 :])
    paths: list[str] = []
    for t in tokens:
        if any(t.startswith(r) for r in REDIRECTS):
            mutating = True
            t = t.lstrip("&12>")
            if not t:
                continue
        rel = relative(t, root)
        if rel:
            paths.append(rel)
    if any(t in REDIRECTS for t in tokens):
        mutating = True
    return mutating, paths


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except (ValueError, OSError):
        sys.exit(0)
    tool = event.get("tool_name", "")
    inp = event.get("tool_input") or {}
    repo = repo_paths(Path(event.get("cwd") or "."))
    if repo is None:
        sys.exit(0)
    root, git_dir = repo
    patterns = lock_patterns(git_dir)
    if patterns is None:
        sys.exit(0)
    ledger = root / LEDGER_REL
    allowed = approved_files(read_text(ledger))

    if tool in FILE_TOOLS:
        target = inp.get("file_path") or inp.get("notebook_path") or ""
        rel = relative(str(target), root)
        if rel is None:
            sys.exit(0)
        if rel == LEDGER_REL:
            check_ledger_edit(tool, inp, ledger)
            sys.exit(0)
        if matches(rel, patterns) and rel not in allowed:
            block(
                f"{rel} 는 잠긴 테스트야. 스펙이 바뀌어 고쳐야 하면 sos:regress 로 "
                "TEST-LEDGER.md 에 줄을 추가하고 사람 승인을 받아. 테스트가 틀렸다고 보이면 멈추고 물어봐."
            )
        sys.exit(0)

    if tool == "Bash":
        mutating, paths = bash_targets(str(inp.get("command", "")), root)
        if not mutating:
            sys.exit(0)
        for rel in paths:
            if rel == LEDGER_REL:
                block("TEST-LEDGER.md 는 셸 명령으로 고치지 않는다. Edit 도구로 승인 칸을 비운 채 줄을 추가해.")
            if matches(rel, patterns) and rel not in allowed:
                block(f"{rel} 는 잠긴 테스트라 셸 명령으로 바꿀 수 없어.")
    sys.exit(0)


if __name__ == "__main__":
    main()
