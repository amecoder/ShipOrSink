#!/usr/bin/env python3
"""hooklib.py — pre-tool-use-guard.sh / test-receipt.sh 가 공유하는 명령 분석·영수증 저장소.

정규식으로 명령 문자열을 훑는 대신 셸이 보는 대로 토큰화(shlex)해서 판정한다.
  `git "push"` · `git p''ush` · `\\git push` · `command git push` · `git -C dir push` · `gh pr new` 처럼
  문자열은 달라도 토큰은 같은 변형을 한 곳에서 처리한다.

서브커맨드:
  analyze-guard    stdin=훅 JSON → 줄 단위 출력 (command / file_path / cwd / flags)
                   JSON 객체가 아니거나 분석 중 예외 → exit 3 (가드가 fail-closed 로 차단)
  analyze-receipt  stdin=훅 JSON → 줄 단위 출력 (command / verdict)
  receipt-has      <receipts.json> <tree>            → exit 0/1
  receipt-latest   <receipts.json>                   → 가장 최근 영수증 트리 (없으면 exit 1)
  receipt-record   <receipts.json> <tree> <head> <command>

stdlib 만 사용한다 (jq 의존 없음).
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
import time
from typing import Any

# ─── 공통: 명령 정규화·분할 ────────────────────────────────────────────────


# 실행을 다른 프로그램에 위임하는 원시어 — 문자열 안에 무엇이 있는지 알 수 없다
INDIRECT_TOKENS = {
    "sh",
    "bash",
    "zsh",
    "dash",
    "ksh",
    "eval",
    "exec",
    "xargs",
    "source",
    ".",
}
INDIRECT_LANGS = {"python", "python3", "perl", "ruby", "node", "deno", "bun"}

# 앞에 붙어도 뒤 명령의 의미를 바꾸지 않는 래퍼 (뒤에 인자를 하나 먹는 것은 값에 표시)
WRAPPERS_NOARG = {
    "rtk",
    "command",
    "env",
    "nohup",
    "nice",
    "sudo",
    "doas",
    "time",
    "builtin",
    "exec",
}
WRAPPERS_ONEARG = {"timeout"}
WRAPPERS_MULTI = (
    ("uv", "run"),
    ("poetry", "run"),
    ("pipenv", "run"),
    ("bundle", "exec"),
    ("pnpm", "exec"),
    ("pnpm", "dlx"),
    ("yarn", "exec"),
)
WRAPPERS_SINGLE_RUNNER = {"npx", "bunx"}

READ_ONLY_HEADS = {
    "jq",
    "yq",
    "awk",
    "cut",
    "sort",
    "uniq",
    "tr",
    "nl",
    "tac",
    "column",
    "od",
    "xxd",
    "hexdump",
    "strings",
    "md5sum",
    "sha256sum",
    "shasum",
    "cmp",
    "cat",
    "less",
    "more",
    "head",
    "tail",
    "grep",
    "rg",
    "diff",
    "bat",
    "wc",
    "ls",
    "eza",
    "stat",
    "file",
    "find",
    "fd",
    "echo",
    "printf",
    "pwd",
    "whoami",
    "date",
    "which",
    "type",
    "true",
    "test",
    "[",
}
GIT_READ_ONLY = {
    "status",
    "log",
    "diff",
    "show",
    "branch",
    "rev-parse",
    "ls-files",
    "blame",
    "describe",
    "remote",
    "config",
    "stash",
    "tag",
    "help",
    "worktree",
    "cat-file",
    "write-tree",
    "check-ignore",
}

# push · pulls · send-pack · pr create/new · pull-request 가 "독립 단어"로 등장 (pre-push 처럼 하이픈으로 이어진 것은 제외)
PUSH_WORD_RE = re.compile(
    r"(?<![\w-])(push|pulls|send-pack|pull-request|pr\s+(create|new))(?![\w-])"
)

SENSITIVE_PATH_RE = re.compile(
    r"(^|/)\.claude/(hooks/|settings(\.local)?\.json$|receipts)|(^|/)claude/receipts"
)


def join_lines(command: str) -> str:
    """여러 줄 명령을 한 줄로 — 둘째 줄 이후도 검사 대상이 되게 한다."""
    # 줄 끝 \ 는 셸에서 줄 잇기 — 구분자로 바꾸면 명령이 둘로 갈라져 분석 불가가 된다
    return command.replace("\r", "").replace("\\\n", " ").replace("\n", " ; ")


def split_segments(command: str) -> list[tuple[str, str]]:
    """'op, segment' 목록. 첫 세그먼트의 op 는 ''.

    따옴표를 아는 상태 기계 — `grep "push|reset" a.sh` 의 `|` 처럼 따옴표 안의 연산자는 구분자가 아니다.
    작은따옴표 안은 이스케이프가 없고, 큰따옴표 안과 밖에서는 `\\` 가 다음 글자를 이스케이프한다.
    """
    segments: list[tuple[str, str]] = []
    buf: list[str] = []
    op = ""
    quote = ""
    i = 0
    n = len(command)

    def flush(next_op: str) -> None:
        nonlocal op
        seg = "".join(buf).strip()
        if seg:
            segments.append((op, seg))
        buf.clear()
        op = next_op

    while i < n:
        c = command[i]
        if quote == "'":
            buf.append(c)
            if c == "'":
                quote = ""
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            buf.append(command[i : i + 2])
            i += 2
            continue
        if quote == '"':
            buf.append(c)
            if c == '"':
                quote = ""
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            buf.append(c)
            i += 1
            continue
        two = command[i : i + 2]
        if two in ("||", "&&"):
            flush(two)
            i += 2
        elif c in (";", "|", "\n"):
            flush(c)
            i += 1
        else:
            buf.append(c)
            i += 1
    flush("")
    return segments


def is_compound(command: str) -> bool:
    """따옴표 밖에 연산자가 있거나 명령 치환이 있으면 복합 명령."""
    segs = split_segments(command)
    return (
        len(segs) > 1 or any(op for op, _ in segs) or "$(" in command or "`" in command
    )


def tokens_of(segment: str) -> list[str]:
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        # 닫히지 않은 따옴표 등 — 분석 불가는 보수적으로 "위임 실행" 취급
        return ["__UNPARSEABLE__"]


def strip_wrappers(tokens: list[str]) -> list[str]:
    """rtk · env VAR=x · command · timeout 60 · uv run … 을 벗긴다. 결과의 첫 토큰이 실제 명령."""
    toks = list(tokens)
    changed = True
    while changed and toks:
        changed = False
        head = toks[0]
        if head in WRAPPERS_NOARG:
            toks = toks[1:]
            # env -i · env -u VAR · env -C dir … : env 의 옵션도 벗긴다
            while head == "env" and toks and toks[0].startswith("-"):
                toks = (
                    toks[2:]
                    if toks[0] in ("-u", "--unset", "-C", "--chdir")
                    else toks[1:]
                )
            # env VAR=val … : 대입 토큰도 벗긴다
            while toks and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", toks[0]):
                toks = toks[1:]
            changed = True
            continue
        if head in WRAPPERS_ONEARG and len(toks) >= 2:
            toks = toks[2:]
            changed = True
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", head):  # VAR=val cmd
            toks = toks[1:]
            changed = True
            continue
        for pair in WRAPPERS_MULTI:
            if tuple(toks[:2]) == pair:
                toks = toks[2:]
                changed = True
                break
        if changed:
            continue
        if head in WRAPPERS_SINGLE_RUNNER and len(toks) >= 2:
            toks = toks[1:]
            changed = True
            continue
    return toks


REDIRECT_RE = re.compile(r"^\d*[<>]")


def strip_redirections(tokens: list[str]) -> list[str]:
    """`2>&1` · `>out.log` · `>> f` · `< in` 을 인자 목록에서 뺀다 (shlex 는 리다이렉션을 모른다)."""
    out: list[str] = []
    skip_next = False
    for t in tokens:
        if skip_next:
            skip_next = False
            continue
        if REDIRECT_RE.match(t):
            # `>` `>>` `2>` `&>` 처럼 대상이 다음 토큰에 있는 형태
            if t.rstrip("&").endswith((">", "<")) and not t.endswith("&"):
                skip_next = True
            continue
        out.append(t)
    return out


def basename_cmd(token: str) -> str:
    """/usr/bin/git · \\git → git"""
    return token.lstrip("\\").rsplit("/", 1)[-1]


# ─── analyze-guard ─────────────────────────────────────────────────────────

GIT_GLOBAL_WITH_ARG = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--exec-path",
    "--config-env",
}


def current_branch(repo_dir: str) -> str:
    """repo_dir 의 현재 브랜치 이름 (detached·저장소 아님이면 '')."""
    try:
        out = subprocess.run(
            ["git", "-C", repo_dir, "symbolic-ref", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def analyze_git(
    tokens: list[str],
    flags: set[str],
    values: dict[str, list[str]],
    base_dir: str = "",
) -> None:
    """tokens[0] 이 git 인 세그먼트. push / send-pack 이면 flags 에 기록.

    base_dir 은 명령이 실행되는 디렉터리 — `-C <dir>` 는 여기에 상대적이고,
    refspec 의 `HEAD`·`@` 는 그 저장소의 현재 브랜치로 풀어 main/master 여부를 본다.
    """
    i = 1
    git_dir = None
    while i < len(tokens) and tokens[i].startswith("-"):
        tok = tokens[i]
        if tok in GIT_GLOBAL_WITH_ARG and i + 1 < len(tokens):
            if tok == "-C":
                git_dir = tokens[i + 1]
            if (
                tok == "-c"
                and "alias." in tokens[i + 1]
                and re.search(r"=(push|send-pack)\b", tokens[i + 1])
            ):
                flags.add("INDIRECT")
            i += 2
        else:
            if tok.startswith("-C") and len(tok) > 2:
                git_dir = tok[2:]
            i += 1
    if i >= len(tokens):
        return
    sub = tokens[i]
    if sub.startswith("$") or sub == "__UNPARSEABLE__":
        flags.add("INDIRECT")
        return
    if (
        sub == "config"
        and any("alias." in t for t in tokens[i:])
        and any(re.search(r"\b(push|send-pack)\b", t) for t in tokens[i:])
    ):
        flags.add("INDIRECT")
        return
    if sub not in ("push", "send-pack"):
        return
    if git_dir:
        values.setdefault("GITDIR", []).append(git_dir)
    flags.add("PUSH")
    rest = tokens[i + 1 :]
    positional: list[str] = []
    j = 0
    while j < len(rest):
        t = rest[j]
        if t in ("--help", "-h"):
            flags.add("HELP")
        elif t in ("--dry-run", "-n"):
            flags.add("DRYRUN")
        elif t in ("--force", "-f") or t.startswith("--force="):
            flags.add("FORCE")
        elif t.startswith("--force-with-lease") or t.startswith("--force-if-includes"):
            pass  # 허용 (lease 는 안전한 force)
        elif re.match(r"^-[a-zA-Z]*f[a-zA-Z]*$", t):  # -fu, -uf 같은 묶음
            flags.add("FORCE")
        elif t in ("--all", "--mirror", "--branches"):
            flags.add("ALL")
        elif t in ("--tags",):
            flags.add("TAGS")
        elif t in ("--delete", "-d"):
            flags.add("DELETE")
        elif t in (
            "--repo",
            "-o",
            "--push-option",
            "--receive-pack",
            "--exec",
            "--recurse-submodules",
            "--signed",
        ):
            j += 1  # 값 하나 소비
        elif t.startswith("-"):
            pass
        else:
            positional.append(t)
        j += 1
    # positional: [remote] [refspec…]
    refspecs = positional[1:] if positional else []
    if not refspecs:
        if "DELETE" in flags and len(positional) >= 1:
            pass
        elif "TAGS" in flags or "ALL" in flags:
            pass
        else:
            flags.add("NOREFSPEC")  # 현재 브랜치 → bash 가 main 인지 확인
    branch_cache: list[str] = []

    def resolve_head(ref: str) -> str:
        if ref not in ("HEAD", "@"):
            return ref
        if not branch_cache:
            repo_dir = os.path.join(base_dir or os.getcwd(), git_dir or "")
            branch_cache.append(current_branch(repo_dir))
        return branch_cache[0] or ref

    for spec in refspecs:
        if spec.startswith("+"):
            flags.add("FORCE")
            spec = spec[1:]
        if "DELETE" in flags:
            dst = spec
            src = ""
        elif ":" in spec:
            src, dst = spec.split(":", 1)
            dst = resolve_head(dst)
        else:
            src, dst = spec, resolve_head(spec)  # 대상 생략 = 소스와 같은 이름
        if re.match(r"^(refs/heads/)?(main|master)$", dst):
            flags.add("MAIN")
        if src:
            values.setdefault("SRC", []).append(src)
        else:
            flags.add("DELETE")


def analyze_gh(
    tokens: list[str], flags: set[str], values: dict[str, list[str]], base_dir: str = ""
) -> None:
    i = 1
    while i < len(tokens) and tokens[i].startswith("-"):
        if tokens[i] in ("-R", "--repo") and i + 1 < len(tokens):
            i += 2
        else:
            i += 1
    if i >= len(tokens):
        return
    sub = tokens[i]
    rest = tokens[i + 1 :]
    if sub == "pr" and rest and rest[0] in ("create", "new"):
        flags.add("PRCREATE")
        if any(t in ("--help", "-h") for t in rest):
            flags.add("HELP")
        for k, t in enumerate(rest):
            if t in ("--head", "-H") and k + 1 < len(rest):
                values.setdefault("SRC", []).append(rest[k + 1])
            elif t.startswith("--head="):
                values.setdefault("SRC", []).append(t.split("=", 1)[1])
    elif sub == "api" and any(re.search(r"/pulls(/|$|\?)", t) for t in rest):
        method_post = any(
            t in ("-X", "--method")
            and k + 1 < len(rest)
            and rest[k + 1].upper() in ("POST", "PUT", "PATCH")
            for k, t in enumerate(rest)
        ) or any(t in ("-f", "-F", "--input", "--field", "--raw-field") for t in rest)
        if method_post:
            flags.add("PRCREATE")
    elif (
        sub == "alias"
        and rest
        and rest[0] == "set"
        and any(re.search(r"\bpr\b.*\b(create|new)\b|/pulls", t) for t in rest[1:])
    ):
        flags.add("INDIRECT")  # 별칭 뒤에 숨긴 PR 생성
    elif sub.startswith("$"):
        flags.add("INDIRECT")
    if ap_label_write(sub, rest, base_dir):
        flags.add("APLABEL")


# ap:* 라벨(판정 채점 ap:ok · ap:wrong · ap:under-tier · 심각 결함 ap:s0 · ap:s1)은 사람만 단다
AP_LABEL_RE = re.compile(r"(?:^|[\s,=\[\]/'\"])ap(?::|%3a)", re.IGNORECASE)
GH_FIELD_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input")
GQL_LABEL_MUTATION_RE = re.compile(
    r"\b(add|remove|clear)LabelsTo(Labelable)?|\b(remove|clear)LabelsFromLabelable|\b(create|update|delete)Label\b",
    re.IGNORECASE,
)


def input_files_text(rest: list[str], base_dir: str) -> list[str]:
    """gh api 의 --input 파일 · -F k=@파일 내용 (일반 파일 · 1MB 까지)."""
    paths: list[str] = []
    for k, t in enumerate(rest):
        if t == "--input" and k + 1 < len(rest):
            paths.append(rest[k + 1])
        elif t.startswith("--input="):
            paths.append(t.split("=", 1)[1])
        elif t in ("-F", "--field") and k + 1 < len(rest) and "=@" in rest[k + 1]:
            paths.append(rest[k + 1].split("=@", 1)[1])
        elif t.startswith("--field=") and "=@" in t[8:]:
            paths.append(t[8:].split("=@", 1)[1])
    out: list[str] = []
    for p in paths:
        full = p if os.path.isabs(p) else os.path.join(base_dir or os.getcwd(), p)
        read = read_script(os.path.expanduser(full))
        if read and not read[1]:
            out.append(read[0])
    return out


def ap_label_write(sub: str, rest: list[str], base_dir: str = "") -> bool:
    """gh 명령이 ap:* 라벨을 달거나 떼거나, 이름 없이 PR 의 라벨 목록을 바꾸면 True."""
    if not rest:
        return False
    if sub in ("pr", "issue") and rest[0] in ("create", "new"):
        for k, t in enumerate(rest):
            if t in ("--label", "-l") and k + 1 < len(rest):
                if AP_LABEL_RE.search(" " + rest[k + 1]):
                    return True
            elif t.startswith("--label=") and AP_LABEL_RE.search(
                " " + t.split("=", 1)[1]
            ):
                return True
        return False
    if sub in ("pr", "issue") and rest[0] == "edit":
        for k, t in enumerate(rest):
            if t in ("--add-label", "--remove-label") and k + 1 < len(rest):
                if AP_LABEL_RE.search(" " + rest[k + 1]):
                    return True
            elif t.startswith(("--add-label=", "--remove-label=")):
                if AP_LABEL_RE.search(" " + t.split("=", 1)[1]):
                    return True
        return False
    if sub == "label" and rest[0] in ("create", "edit", "delete"):
        return any(AP_LABEL_RE.search(" " + t) for t in rest[1:])
    if sub != "api":
        return False
    method = ""
    for k, t in enumerate(rest):
        if t in ("-X", "--method") and k + 1 < len(rest):
            method = rest[k + 1].upper()
        elif t.startswith(("-X", "--method=")) and len(t) > 2:
            method = t.split("=", 1)[1].upper() if "=" in t else t[2:].upper()
    has_fields = any(
        t in GH_FIELD_FLAGS or t.startswith(("--field=", "--raw-field=")) for t in rest
    )
    if not method:
        method = "POST" if has_fields else "GET"
    if method == "GET":
        return False
    paths = [t for t in rest if not t.startswith("-")]
    texts = rest + input_files_text(rest, base_dir)
    if "graphql" in paths:
        return any(GQL_LABEL_MUTATION_RE.search(t) for t in texts)
    if any(AP_LABEL_RE.search(" " + t) for t in texts):
        return True
    for p in paths:
        # 목록 교체(PUT) · 전부 삭제(DELETE) — 이름을 쓰지 않고 ap:* 를 지운다
        if re.search(r"/issues/\d+/labels/?(\?|$)", p) and method in ("PUT", "DELETE"):
            return True
        # 이슈·PR 수정(PATCH)의 labels 필드는 목록 전체를 바꾼다
        if re.search(r"/(issues|pulls)/\d+/?(\?|$)", p) and any(
            re.match(r"labels(\[|=|$)", f) for f in rest
        ):
            return True
    return False


def analyze_rm(tokens: list[str], flags: set[str]) -> None:
    opts = [t for t in tokens[1:] if t.startswith("-")]
    args = [t for t in tokens[1:] if not t.startswith("-")]
    recursive = any(
        t in ("-r", "-R", "--recursive") or re.match(r"^-[a-zA-Z]*[rR]", t)
        for t in opts
    )
    force = any(t in ("-f", "--force") or re.match(r"^-[a-zA-Z]*f", t) for t in opts)
    if "--no-preserve-root" in opts:
        flags.add("RMRF")
        return
    if recursive and force:
        home = os.environ.get("HOME", "")
        for a in args:
            a2 = a.rstrip("/") or "/"
            if a2 in ("/", "/*", "~", "~/*", "..", "$HOME", "${HOME}") or (
                home and a2 in (home, home + "/*")
            ):
                flags.add("RMRF")


def env_file_token(tok: str) -> bool:
    base = tok.lstrip("0123456789<>&").rsplit("/", 1)[
        -1
    ]  # `>.env` 처럼 붙은 리다이렉션도
    if not base.startswith(".env") and not base.endswith(".env"):
        return False
    if re.search(r"\.env\.(example|sample|template)$", base) or base in (
        ".env.example",
        ".env.sample",
        ".env.template",
    ):
        return False
    if re.search(r"\.(md|txt|rst)$", base):
        return False
    return True


# .env 라는 이름을 인자로 받아도 파일 내용을 열지 않는 명령 (존재·메타데이터·ignore 여부만 본다)
ENV_NO_OPEN_HEADS = {"test", "[", "[[", "ls", "stat"}
ENV_NO_OPEN_GIT = {"check-ignore", "ls-files"}
# grep 계열: 패턴·glob 값은 파일이 아니다. 값을 받는 옵션 중 파일을 여는 것은 따로 본다
GREP_HEADS = {"grep", "egrep", "fgrep", "rg"}
GREP_FILE_OPTS = {"-f", "--file", "--exclude-from", "--ignore-file"}
GREP_PATTERN_OPTS = {"-e", "--regexp"}
GREP_VALUE_OPTS = {
    "grep": {
        "-m",
        "--max-count",
        "-A",
        "-B",
        "-C",
        "--context",
        "--after-context",
        "--before-context",
        "-d",
        "-D",
        "--directories",
        "--devices",
        "--label",
        "--include",
        "--exclude",
        "--exclude-dir",
        "--binary-files",
    },
    "rg": {
        "-m",
        "--max-count",
        "-A",
        "-B",
        "-C",
        "--context",
        "--after-context",
        "--before-context",
        "-g",
        "--glob",
        "--iglob",
        "-t",
        "--type",
        "-T",
        "--type-not",
        "--type-add",
        "-j",
        "--threads",
        "-M",
        "--max-columns",
        "--max-depth",
        "-E",
        "--encoding",
        "-r",
        "--replace",
        "--sort",
        "--sortr",
    },
}


def grep_opened_args(head: str, args: list[str]) -> list[str]:
    """grep/rg 인자 중 실제로 열리는 파일 인자 (패턴·glob·숫자 값은 제외)."""
    value_opts = GREP_VALUE_OPTS["rg" if head == "rg" else "grep"]
    opened: list[str] = []
    positional: list[str] = []
    pattern_given = False
    end_of_opts = False
    i = 0
    while i < len(args):
        t = args[i]
        if end_of_opts or not t.startswith("-") or t == "-":
            positional.append(t)
        elif t == "--":
            end_of_opts = True
        else:
            name, has_inline, inline = (
                t.partition("=") if t.startswith("--") else (t, "", "")
            )
            nxt = args[i + 1] if i + 1 < len(args) else ""
            if name in GREP_FILE_OPTS:
                pattern_given = True
                opened.append(inline if has_inline else nxt)
                i += 0 if has_inline else 1
            elif not t.startswith("--") and t.startswith("-f") and len(t) > 2:
                pattern_given = True
                opened.append(t[2:])
            elif name in GREP_PATTERN_OPTS:
                pattern_given = True
                i += 0 if has_inline else 1
            elif not t.startswith("--") and t.startswith("-e") and len(t) > 2:
                pattern_given = True
            elif name in value_opts and not has_inline:
                i += 1
        i += 1
    if not pattern_given and positional:
        positional = positional[1:]  # 첫 위치 인자는 패턴
    return opened + positional


def git_subcommand(args: list[str]) -> tuple[str, list[str]]:
    """git 전역 옵션을 건너뛴 (서브커맨드, 그 뒤 인자)."""
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GIT_GLOBAL_WITH_ARG else 1
    return (args[i], args[i + 1 :]) if i < len(args) else ("", [])


def env_opened_tokens(head: str, tokens: list[str]) -> list[str]:
    """.env 검사 대상 토큰 — 리다이렉션 대상은 항상, 그 밖에는 명령이 실제로 열 수 있는 인자만.

    tokens 는 래퍼를 벗긴 세그먼트 전체(명령 이름 포함, 리다이렉션 포함 — `> .env ls` 처럼 앞에 와도 잡는다).
    """
    checked: list[str] = []
    plain: list[str] = []
    take_next = False
    for t in tokens:
        if take_next:
            checked.append(t)
            take_next = False
        elif REDIRECT_RE.match(t):
            checked.append(t)  # `>.env` 처럼 붙은 대상
            take_next = t.rstrip("&").endswith((">", "<")) and not t.endswith("&")
        else:
            plain.append(t)
    plain = plain[1:]  # 명령 이름
    if head in ENV_NO_OPEN_HEADS:
        return checked
    if head == "git" and git_subcommand(plain)[0] in ENV_NO_OPEN_GIT:
        return checked
    if head in GREP_HEADS:
        return checked + grep_opened_args(head, plain)
    return checked + plain


# ─── 스크립트 파일: 실행하는 파일의 내용을 같은 규칙으로 판정한다 ─────────────
SCRIPT_SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "source", "."}
SHEBANG_SHELLS = {"sh", "bash", "zsh", "dash", "ksh"}
SHEBANG_LANGS = {"python", "node", "perl", "ruby", "deno", "bun"}
SCRIPT_MAX_BYTES = 1_000_000
SCRIPT_SCAN_MAX_BYTES = (
    64_000_000  # 1MB 넘는 스크립트는 바이너리 구간 전까지 이만큼만 훑는다
)
SCRIPT_MAX_DEPTH = 3
SCRIPT_MAX_FILES = (
    64  # 한 명령에서 따라가는 스크립트 파일 수 상한 (같은 파일은 한 번만 분석)
)
# 스크립트 본문에서 호출자 판정으로 옮기는 플래그 — push·PR·위임 실행·ap 라벨만.
# HELP·DRYRUN 은 옮기지 않는다(본문 어딘가의 --dry-run 이 진짜 push 를 면제하면 안 된다).
# SENSITIVE_PATH·ENVFILE 은 옮기지 않는다 — apply.sh 처럼 훅을 배치하는 스크립트가 정상 경로다
SCRIPT_CARRY_FLAGS = {
    "PUSH",
    "PRCREATE",
    "FORCE",
    "MAIN",
    "ALL",
    "NOREFSPEC",
    "DELETE",
    "TAGS",
    "INDIRECT",
    "APLABEL",
}
# python·node 등 파일: 셸 문법이 아니라 정규식으로 본다 — 주석 줄을 지운 뒤 한 줄 안에 git … push ·
# gh … pr create · gh … /pulls · gh … ap:* 가 있고, 파일에 프로세스를 띄우는 API 가 있으면 실행으로 본다.
# 따옴표 형태(f-string · raw · 백틱 · 변수 낀 리스트 · 변수에 담은 명령)와 무관하다. 대가: 프로세스 API 를 쓰면서
# 본문 글자로 git push 를 담은 문서 편집 스크립트도 막힌다 — 그런 스크립트는 프로세스를 띄우지 않는다
LANG_CMD_RE = re.compile(
    r"\bgit\b[^\n]{0,80}?\b(?:push|send-pack)\b"
    r"|\bgh\b[^\n]{0,60}?\bpr\b[^\n]{0,20}?\b(?:create|new)\b"
    r"|\bgh\b[^\n]{0,80}?/pulls\b"
    r"|\bgh\b[^\n]{0,80}?(?<![\w-])ap:"
)
LANG_COMMENT_RE = re.compile(r"^\s*(#|//|--|;)")
LANG_PULLS_RE = re.compile(r"/pulls\b")
LANG_SPAWN_RE = re.compile(
    r"\b(subprocess|os\.system|os\.popen|os\.exec\w*|os\.spawn\w*|pty\.spawn|child_process|execSync|"
    r"spawnSync|execFile|Deno\.(run|Command)|Bun\.(spawn|\$)|IPC::Open\d|Open3)\b|\bsystem\s*\(|\bqx\b"
)
LANG_NET_RE = re.compile(
    r"urllib\.request|\brequests\.(?:get|post|put|patch|delete|request|Session)\b|http\.client\.|\bhttpx\."
    r"|\baiohttp\.|\bfetch\(|\baxios[.(]|\bhttps?\.request\(|Net::HTTP\.|LWP::User"
    r"Agent|Faraday\."
)


def read_script(path: str) -> tuple[str, bool] | None:
    """(본문, 1MB 를 넘었는지) — 일반 파일이 아니거나 열 수 없으면 None. 바이너리면 본문 ''."""
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as f:
            data = f.read(SCRIPT_MAX_BYTES + 1)
    except OSError:
        return None
    if b"\0" in data:
        return "", False
    if len(data) > SCRIPT_MAX_BYTES:
        return "", True
    return data.decode("utf-8", errors="replace"), False


def large_script_has_push(path: str) -> bool:
    """1MB 넘는 스크립트(설치 파일 등): 바이너리 구간(NUL) 전까지 push·PR·ap 라벨 단어가 있는지만 본다."""
    tail = b""
    seen = 0
    try:
        with open(path, "rb") as f:
            while seen < SCRIPT_SCAN_MAX_BYTES:
                chunk = f.read(1 << 20)
                if not chunk:
                    return False
                nul = chunk.find(b"\0")
                text = (tail + (chunk if nul < 0 else chunk[:nul])).decode(
                    "utf-8", errors="replace"
                )
                if PUSH_WORD_RE.search(text.lower()) or AP_LABEL_RE.search(text):
                    return True
                if nul >= 0:
                    return False
                tail = chunk[-64:]
                seen += len(chunk)
    except OSError:
        return True
    return False


def shebang_kind(path: str) -> str | None:
    """경로로 직접 실행하는 파일 — 셸 셰뱅·셰뱅 없는 텍스트는 'shell', 언어 셰뱅은 'lang', 그 밖(bats·바이너리)은 None."""
    try:
        with open(path, "rb") as f:
            head = f.read(1024)
    except OSError:
        return None
    if head.startswith(b"\x7fELF") or b"\0" in head:
        return None  # 바이너리 실행 파일(/usr/bin/git 등) — 내용이 아니라 명령으로 판정된다
    if not head.startswith(b"#!"):
        return "shell"  # 셰뱅 없는 텍스트 실행 파일은 셸이 셸 스크립트로 실행한다
    parts = head[2:].split(b"\n", 1)[0].decode("utf-8", errors="replace").split()
    if not parts:
        return "shell"
    prog = parts[0].rsplit("/", 1)[-1]
    if prog == "env":
        rest = [p for p in parts[1:] if not p.startswith("-") and "=" not in p]
        prog = rest[0].rsplit("/", 1)[-1] if rest else ""
    prog = re.sub(r"[\d.]+$", "", prog)
    if prog in SHEBANG_SHELLS:
        return "shell"
    if prog in SHEBANG_LANGS:
        return "lang"
    return None


REDIRECT_IN_RE = re.compile(r"^\d*<(?![<(])(.*)$")


def script_target(
    head: str, toks: list[str], with_redirects: list[str], op: str, base_dir: str
) -> tuple[str, str] | None:
    """이 세그먼트가 실행하는 스크립트 — ('shell'|'lang', 경로) · 무엇이 돌지 모르는 입력이면 ('stdin', '')."""

    def resolve(p: str) -> str:
        p = os.path.expanduser(p)
        return p if os.path.isabs(p) else os.path.join(base_dir, p)

    args = toks[1:]
    if head in SCRIPT_SHELLS or head in INDIRECT_LANGS:
        is_shell = head in SCRIPT_SHELLS
        kind = "shell" if is_shell else "lang"
        if "-c" in args or (not is_shell and any(t in ("-e", "-m") for t in args)):
            return None  # 문자열 실행(-c · -e)은 위임 실행 규칙이, 모듈 실행(-m)은 볼 파일이 없다
        if any(t.startswith(("<(", ">(")) for t in with_redirects):
            return ("stdin", "")  # bash <(…) — 프로세스 치환은 … | bash 와 같다
        for t in args:
            if not t.startswith("-") and os.path.isfile(resolve(t)):
                return (kind, resolve(t))
        for k, t in enumerate(with_redirects):  # bash < f · bash 0< f · bash <f
            m = REDIRECT_IN_RE.match(t)
            if not m:
                continue
            target = m.group(1) or (
                with_redirects[k + 1] if k + 1 < len(with_redirects) else ""
            )
            if not target:
                return None
            path = resolve(target)
            if os.path.isfile(path):
                return (kind, path)
            return ("stdin", "") if os.path.exists(path) else None  # FIFO·장치·디렉터리
        if (
            is_shell
            and head not in ("source", ".")
            and op == "|"
            and not any(not t.startswith("-") for t in args)
        ):
            return ("stdin", "")  # … | bash — 무엇이 실행될지 알 수 없다
        return None
    first = toks[0]
    if "/" in first and os.path.isfile(resolve(first)):
        path = resolve(first)
        kind_or_none = shebang_kind(path)
        return (kind_or_none, path) if kind_or_none else None
    return None


def substitutions(seg: str) -> list[str]:
    """명령 치환 $( … ) · ` … ` 의 본문 — 이스케이프된 \\$( 와 산술 $(( 는 제외. 닫히지 않으면 끝까지."""
    out: list[str] = []
    i, n = 0, len(seg)
    while i < n:
        if seg[i] == "\\":
            i += 2
            continue
        if seg.startswith("$(", i) and not seg.startswith("$((", i):
            level, j = 1, i + 2
            while j < n and level:
                if seg[j] == "\\":
                    j += 2
                    continue
                level += {"(": 1, ")": -1}.get(seg[j], 0)
                j += 1
            out.append(seg[i + 2 : j - 1 if not level else n])
            i = j
            continue
        if seg[i] == "`":
            j = seg.find("`", i + 1)
            out.append(seg[i + 1 : j if j != -1 else n])
            i = n if j == -1 else j + 1
            continue
        i += 1
    return out


def strip_comment_lines(body: str) -> str:
    return "\n".join(ln for ln in body.split("\n") if not ln.lstrip().startswith("#"))


ScriptMemo = dict[str, tuple[frozenset[str], dict[str, list[str]]]]


def follow_script(
    target: tuple[str, str],
    base_dir: str,
    depth: int,
    flags: set[str],
    values: dict[str, list[str]],
    memo: ScriptMemo,
) -> None:
    kind, path = target
    if kind == "stdin":
        flags.add("INDIRECT")
        return
    if path in memo:
        sub_flags, sub_values = memo[path]
    else:
        if len(memo) >= SCRIPT_MAX_FILES:
            flags.add("INDIRECT")  # 따라갈 파일이 너무 많다 — 다 볼 수 없으면 막는다
            return
        sub_flags, sub_values = script_verdict(kind, path, base_dir, depth, memo)
        if depth + 1 > SCRIPT_MAX_DEPTH and kind == "shell":
            memo.pop(
                path, None
            )  # 깊이 제한으로 낸 결과 — 얕은 곳에서 다시 만나면 새로 본다
        else:
            memo[path] = (sub_flags, sub_values)
    flags.update(sub_flags)
    for k, v in sub_values.items():
        values.setdefault(k, []).extend(v)


def is_this_analyzer(path: str) -> bool:
    try:
        return os.path.samefile(path, __file__)
    except OSError:
        return False


def script_verdict(
    kind: str, path: str, base_dir: str, depth: int, memo: ScriptMemo
) -> tuple[frozenset[str], dict[str, list[str]]]:
    memo[path] = (frozenset(), {})  # 자기 호출은 판정 중인 빈 결과로 끊는다
    read = read_script(path)
    if read is None:
        return frozenset(), {}
    body, oversized = read
    if oversized:
        return (
            frozenset({"INDIRECT"}) if large_script_has_push(path) else frozenset()
        ), {}
    if kind == "lang":
        if is_this_analyzer(path):
            return frozenset(), {}  # 분석기 자신은 패턴 글자를 담고 있다
        code = "\n".join(ln for ln in body.split("\n") if not LANG_COMMENT_RE.match(ln))
        hit = (LANG_CMD_RE.search(code) and LANG_SPAWN_RE.search(code)) or (
            LANG_PULLS_RE.search(code) and LANG_NET_RE.search(code)
        )
        return (frozenset({"INDIRECT"}) if hit else frozenset()), {}
    if depth >= SCRIPT_MAX_DEPTH:
        return frozenset({"INDIRECT"}), {}  # 더 따라가지 않는다
    _, _, _, sub_flags, sub_values = analyze_guard(
        {"tool_input": {"command": strip_comment_lines(body)}, "cwd": base_dir},
        depth + 1,
        memo,
    )
    return frozenset(sub_flags & SCRIPT_CARRY_FLAGS), sub_values


# 셸 예약어 — 뒤에 오는 명령이 실제로 실행된다 (if … then git push · { git push; } · ( git push ))
SHELL_RESERVED = {
    "if",
    "then",
    "else",
    "elif",
    "do",
    "while",
    "until",
    "!",
    "{",
    "coproc",
}


def strip_reserved(toks: list[str]) -> list[str]:
    toks = list(toks)
    while toks:
        t = toks[0]
        if t in SHELL_RESERVED:
            toks = toks[1:]
        elif t == "function":  # function f { … } · function f() { … }
            toks = toks[2:]
        elif len(toks) > 1 and toks[1] == "()":  # f () { … }
            toks = toks[2:]
        elif t.startswith("(") and not t.startswith("(("):
            rest = t.lstrip("(")
            toks = ([rest] if rest else []) + toks[1:]
        elif t == "case":  # case WORD in PATTERN) 명령
            k = next((i for i, x in enumerate(toks) if x.endswith(")")), None)
            toks = toks[k + 1 :] if k is not None else []
        elif t.endswith(")") and len(toks) > 1:  # case 패턴 `x)` · 함수 정의 `f()`
            toks = toks[1:]
        else:
            break
    # ( git push origin main) 의 닫는 괄호가 붙은 토큰 — 짝 없는 ) 만 뗀다
    return [
        t.rstrip(")") if t.endswith(")") and t.count("(") < t.count(")") else t
        for t in toks
    ]


def strip_prefixes(toks: list[str]) -> list[str]:
    """예약어와 래퍼가 섞여 앞에 붙은 것(then timeout 5 git …)을 더 바뀌지 않을 때까지 벗긴다."""
    while True:
        nxt = strip_wrappers(strip_reserved(toks))
        if nxt == toks:
            return toks
        toks = nxt


def analyze_guard(
    data: dict[str, Any],
    depth: int = 0,
    memo: ScriptMemo | None = None,
) -> tuple[str, str, str, set[str], dict[str, list[str]]]:
    memo = {} if memo is None else memo
    raw_input = data.get("tool_input")
    tool_input: dict[str, Any] = raw_input if isinstance(raw_input, dict) else {}
    command = tool_input.get("command") or data.get("command") or ""
    file_path = (
        tool_input.get("file_path")
        or tool_input.get("path")
        or data.get("file_path")
        or data.get("path")
        or ""
    )
    cwd = data.get("cwd") or ""
    flags: set[str] = set()
    values: dict[str, list[str]] = {}
    joined = join_lines(command)
    if not joined.strip():
        return joined, file_path, cwd, flags, values

    if is_compound(joined):
        flags.add("COMPOUND")
    base_dir = cwd or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    lowered = joined.lower()
    # 'pre-push' · 'pushed' 같은 파일명·단어는 제외 — push 가 독립 단어로 나올 때만 (하이픈도 경계로 보지 않는다)
    has_push_word = bool(PUSH_WORD_RE.search(lowered))
    if depth == 0 and ("$(" in command or "`" in command) and has_push_word:
        flags.add("INDIRECT")

    for op, seg in split_segments(joined):
        # 스크립트 본문(depth>0)은 세그먼트 단위로 본다 — 파일 어딘가의 push 단어가 무관한 xargs·eval 을 막지 않게
        seg_push = (
            has_push_word if depth == 0 else bool(PUSH_WORD_RE.search(seg.lower()))
        )
        if depth > 0 and seg_push:
            # 스크립트 본문의 명령 치환은 괄호 안 명령을 같은 규칙으로 판정한다
            for sub in substitutions(seg):
                if depth >= SCRIPT_MAX_DEPTH:
                    flags.add("INDIRECT")
                    break
                _, _, _, sub_flags, sub_values = analyze_guard(
                    {"tool_input": {"command": sub}, "cwd": base_dir}, depth + 1, memo
                )
                flags.update(sub_flags & SCRIPT_CARRY_FLAGS)
                for k, v in sub_values.items():
                    values.setdefault(k, []).extend(v)
        raw = tokens_of(seg)
        if raw == ["__UNPARSEABLE__"]:
            if seg_push:
                flags.add("INDIRECT")
            continue
        # 리다이렉션 대상(>> .env)까지 포함한 인자 · 앞에 붙은 예약어(then · { · ( …)와 래퍼를 벗긴다
        with_redirects = strip_prefixes(raw)
        toks = strip_redirections(with_redirects)
        if not toks:
            continue
        head = basename_cmd(toks[0])
        if head in INDIRECT_TOKENS or (
            head in INDIRECT_LANGS and any(t in ("-c", "-e") for t in toks[1:])
        ):
            if seg_push:
                flags.add("INDIRECT")
        target = script_target(head, toks, with_redirects, op, base_dir)
        if target:
            follow_script(target, base_dir, depth, flags, values, memo)
        if head in ("curl", "wget") and re.search(
            r"api\.github\.com/repos/[^ ]+/pulls", seg
        ):
            flags.add("PRCREATE")
        if head == "git":
            analyze_git([head] + toks[1:], flags, values, base_dir)
        elif head == "hub" and len(toks) > 1 and toks[1] == "pull-request":
            flags.add("PRCREATE")
        elif head == "gh":
            analyze_gh([head] + toks[1:], flags, values, base_dir)
        elif head == "rm":
            analyze_rm([head] + toks[1:], flags)
        # .env 파일을 여는 명령 (읽기 포함 — settings deny Read(.env) 와 같은 수준).
        # grep 패턴·git check-ignore·ls·test 처럼 이름만 참조하고 열지 않는 인자는 제외
        if any(env_file_token(t) for t in env_opened_tokens(head, with_redirects)):
            flags.add("ENVFILE")
        # 훅·설정·영수증 경로: 읽기 전용 명령이 아니거나 리다이렉션이 있으면 차단
        if any(SENSITIVE_PATH_RE.search(t) for t in raw):
            sed_in_place = head == "sed" and any(
                t == "-i" or t.startswith("-i") or t == "--in-place" for t in toks[1:]
            )
            # git add 는 파일 내용을 그대로 스테이징할 뿐이다 — 단 --chmod 는 실행 비트를 바꾼다
            git_add_as_is = (
                head == "git"
                and len(toks) > 1
                and toks[1] == "add"
                and not any(t.startswith("--chmod") for t in toks[2:])
            )
            is_read = (
                head in READ_ONLY_HEADS
                or (head == "sed" and not sed_in_place)
                or (head == "git" and len(toks) > 1 and toks[1] in GIT_READ_ONLY)
                or git_add_as_is
            )
            has_redirect = any(t in (">", ">>", "|") or t.startswith(">") for t in raw)
            if not is_read or has_redirect:
                flags.add("SENSITIVE_PATH")
    # 단순 읽기 전용 판정 (quick-exit 용): 연산자 없음 + 첫 토큰이 읽기 전용
    if "COMPOUND" not in flags:
        raw = strip_wrappers(tokens_of(joined))
        if raw:
            head = basename_cmd(raw[0])
            if (
                head in READ_ONLY_HEADS
                and "ENVFILE" not in flags
                and "SENSITIVE_PATH" not in flags
            ):
                flags.add("SIMPLE_READ_ONLY")
            elif (
                head == "git"
                and len(raw) > 1
                and raw[1] in GIT_READ_ONLY
                and "SENSITIVE_PATH" not in flags
            ):
                flags.add("SIMPLE_READ_ONLY")
    return joined, file_path, cwd, flags, values


# ─── analyze-receipt ───────────────────────────────────────────────────────

RUNNER_SEQUENCES = [
    ("pytest",),
    ("python", "-m", "pytest"),
    ("python3", "-m", "pytest"),
    ("tox",),
    ("nox",),
    ("vitest",),
    ("jest",),
    ("mocha",),
    ("ava",),
    ("playwright", "test"),
    ("cypress", "run"),
    ("go", "test"),
    ("cargo", "test"),
    ("cargo", "nextest", "run"),
    ("./gradlew", "test"),
    ("./gradlew", "check"),
    ("gradlew", "test"),
    ("gradle", "test"),
    ("gradle", "check"),
    ("./mvnw", "test"),
    ("./mvnw", "verify"),
    ("mvn", "test"),
    ("mvn", "verify"),
    ("dotnet", "test"),
    ("flutter", "test"),
    ("dart", "test"),
    ("swift", "test"),
    ("xcodebuild", "test"),
    ("rspec",),
    ("rake", "test"),
    ("rails", "test"),
    ("bats",),
    ("make", "test"),
    ("make", "check"),
    ("deno", "test"),
    ("mix", "test"),
    ("phpunit",),
    ("php", "artisan", "test"),
    ("ctest",),
]
PKG_MANAGERS = {"npm", "pnpm", "yarn", "bun"}
# 패키지 매니저 바로 뒤의 "이 디렉터리에서 실행" 옵션 — 모노레포 하위 패키지·다른 저장소 클론 (측정 발견 4)
PKG_DIR_FLAGS = {
    "pnpm": ("-C", "--dir"),
    "npm": ("-C", "--prefix"),  # npm 의 -C 는 --prefix 별칭
    "yarn": ("--cwd",),
    "bun": ("--cwd",),
}
TEST_SCRIPT_RE = re.compile(r"^test(:(unit|integration|int|e2e|all|ci|cov|coverage))?$")

# 테스트를 실제로 돌리지 않거나 일부만 고르는 옵션
EXCLUDED_FLAGS = {
    "--version",
    "-V",
    "--help",
    "-h",
    "--collect-only",
    "--co",
    "--list-tests",
    "--listTests",
    "--list",
    "--dry-run",
    "--no-run",
    "--count",
    "-DskipTests",
    "-Dmaven.test.skip=true",
    "--passWithNoTests",
    "--watch",
    "--watchAll",
    "-w",
    "--ui",
    "--init",
    "--showConfig",
    "-k",
    "-m",
    "--testPathPattern",
    "--testPathPatterns",
    "-t",
    "--testNamePattern",
    "--filter",
    "--grep",
    "-g",
    "-run",
    "--run-filter",
    "--only",
    "--skip",
    # 다른 루트를 돌리거나 바뀐 파일·실패한 것·한 조각만 고르는 Vitest·Jest 옵션 (Codex 리뷰 PR #49)
    "--root",  # 짧은 -r 은 뺀다 — mocha -r(모듈 미리 불러오기)·bats -r(재귀)는 전체 실행이다
    "--rootDir",
    "--roots",
    "--dir",
    "--pass-with-no-tests",
    "--onlyChanged",
    "--findRelatedTests",
    "--lastCommit",
    "--onlyFailures",
    "--shard",
}
EXCLUDED_PREFIXES = (
    "--collect-only",
    "--list",
    "-DskipTests",
    "-Dmaven.test.skip",
    "--dry-run",
    "--no-run",
    "--testPathPattern",
    "--testNamePattern",
    "--filter=",
    "--grep=",
    "-run=",
    "--changed",
)


def norm_long_opt(a: str) -> str:
    """긴 옵션 이름을 표기와 무관하게 — `--onlyChanged` · `--only-changed` · `--rootDir=x` → `onlychanged` · `rootdir`.
    Vitest·Jest 는 camelCase 와 kebab-case 를 모두 받는다 (Codex 리뷰)"""
    return a[2:].split("=", 1)[0].replace("-", "").lower()


EXCLUDED_LONG = {norm_long_opt(f) for f in EXCLUDED_FLAGS if f.startswith("--")}
EXCLUDED_LONG_PREFIXES = tuple(
    norm_long_opt(p) for p in EXCLUDED_PREFIXES if p.startswith("--")
)
# 짧은 옵션·하위 명령은 러너마다 뜻이 달라 Vitest·Jest·패키지 스크립트(러너를 모름)에서만 본다 —
# jest -o(바뀐 파일만) · -f(실패한 것만)는 부분 실행이지만 pytest -o(설정 덮어쓰기) · rspec -f(출력 형식)는 전체 실행
JS_RUNNERS = {"vitest", "jest", "script"}
JS_EXCLUDED_SHORT = {"-o", "-f"}
# 대상 테스트를 고르는 Vitest·Jest 옵션 (Codex 리뷰)
JS_EXCLUDED_LONG = {
    norm_long_opt(f)
    for f in (
        "--project",
        "--exclude",
        "--testMatch",
        "--testRegex",
        "--selectProjects",
        "--testPathIgnorePatterns",
        "--runTestsByPath",
    )
}
# 러너 바로 뒤(또는 `--` 바로 뒤) 첫 인자로 오면 테스트를 돌리지 않거나 일부만 돌리는 하위 명령 —
# `vitest list` · `vitest related a.ts` · `pnpm test -- list`
RUNNER_SUBCOMMANDS = {"list", "related", "bench"}


def is_excluded_arg(a: str, runner: str) -> bool:
    if a in EXCLUDED_FLAGS or any(a.startswith(p) for p in EXCLUDED_PREFIXES):
        return True
    if runner not in JS_RUNNERS:
        return False
    # 표기 정규화는 Vitest·Jest 만 — pytest --rootdir · --count=3 은 전체 실행이다 (Codex 리뷰)
    if a.startswith("--") and len(a) > 2:
        name = norm_long_opt(a)
        return (
            name in EXCLUDED_LONG
            or name in JS_EXCLUDED_LONG
            or name.startswith(EXCLUDED_LONG_PREFIXES)
        )
    return a in JS_EXCLUDED_SHORT


def match_runner(toks: list[str]) -> tuple[bool, list[str], str]:
    """(러너인가, 러너 뒤 인자들, 러너 이름 — 패키지 매니저의 test 스크립트는 "script")"""
    for seq in RUNNER_SEQUENCES:
        n = len(seq)
        if (
            len(toks) >= n
            and tuple(basename_cmd(t) if i == 0 else t for i, t in enumerate(toks[:n]))
            == seq
        ):
            return True, toks[n:], seq[0]
    if toks and toks[0] in PKG_MANAGERS and len(toks) >= 2:
        rest = toks[1:]
        if rest[0] in ("run", "run-script") and len(rest) >= 2:
            rest = rest[1:]
        if TEST_SCRIPT_RE.match(rest[0]) or rest[0] == "t":
            return True, rest[1:], "script"
        if toks[0] in ("pnpm", "yarn", "bun") and rest[0] in (
            "vitest",
            "jest",
            "playwright",
        ):
            return match_runner(rest)
    return False, [], ""


# 형식(`=`·`+=`·`env --split-string=…`)을 가리지 않고 토큰 어디든 있으면 거부 (Codex 리뷰 PR #49)
NPM_CONFIG_ENV = re.compile(r"npm_config_", re.IGNORECASE)
# 환경을 바꾸는 명령에 `$` 가 있으면 어떤 변수가 설정될지 분석기가 알 수 없다 (`export "${A}${B}=…"`)
ENV_SETTERS = frozenset(
    {"export", "declare", "typeset", "readonly", "local", "eval", "env", "set"}
)


PKG_DIR_FLAG = re.compile(r"(^|\s)(-C|--dir|--prefix|--cwd)(=|\s|$)")
# 디렉터리 옵션이 있는 명령에 허용하는 문자 — 막을 문자를 늘려 가지 않고 허용 문자만 둔다 (Codex 리뷰 PR #49).
# 그 밖의 것(`&` 백그라운드 · `|` · `$` · 백틱 · 괄호 · 글로브 `*?[` · `~` · `\` · 제어 문자 · 비ASCII)은 셸과
# 분석기의 해석이 갈릴 수 있다 — 예: `pnpm -C x[ab] test` 는 셸이 xa 로 펼치는데 분석기는 글자 그대로 본다
# 따옴표도 뺀다 — 따옴표 안의 `'>'` 를 분석기는 리다이렉션으로 지우지만 셸은 인자로 넘긴다 (Codex 리뷰 PR #49)
PKG_DIR_SAFE = re.compile(r"[A-Za-z0-9 _./=:@+,<>-]*")


def has_pkg_dir_flag(command: str, segments: list[tuple[str, str]]) -> bool:
    """디렉터리 옵션이 어디든 있는가 — 따옴표로 감싼 옵션(`'--dir'`)도 토큰으로 본다."""
    if PKG_DIR_FLAG.search(command):
        return True
    for _, seg in segments:
        for t in tokens_of(seg):
            if t in ("-C", "--dir", "--prefix", "--cwd") or t.startswith(
                ("-C", "--dir=", "--prefix=", "--cwd=")
            ):
                return True
    return False


def compound_pkg_dir(
    command: str, segments: list[tuple[str, str]], raw_command: str
) -> bool:
    """디렉터리 옵션이 단독 명령이 아닌 곳에 있는가. 앞 명령이 환경을 바꾸는 형태는 끝없이 많아
    (`set -a; printf -v …` · `builtin export` · `{ …; }`) 막을 목록을 만들지 않고, 디렉터리 옵션은
    허용 문자로만 된 단독 명령에서만 인정한다 (Codex 리뷰 PR #49).
    허용 문자는 join_lines 전 원문으로 본다 — join_lines 는 따옴표 안의 `\\r` 까지 지운다. 원문의 개행은
    join_lines 가 세그먼트를 나누므로 단독 명령이 아니게 된다."""
    if not has_pkg_dir_flag(command, segments):
        return False
    bare = re.sub(r"^(rtk\s+)+", "", raw_command.strip())
    # 첫 단어가 패키지 매니저 자체여야 한다 — `env PATH=… pnpm` · `X=… pnpm` 은 다른 실행 파일을 부를 수 있다
    first = bare.split(" ", 1)[0]
    return (
        len(segments) != 1
        or not PKG_DIR_SAFE.fullmatch(bare)
        or first not in PKG_MANAGERS
    )


def sets_env_config(segments: list[tuple[str, str]]) -> bool:
    """npm_config_* 를 정하거나, 환경을 바꾸는 명령이 `$` 로 이름·값을 조립하는가 (Codex 리뷰 PR #49)."""
    for _, seg in segments:
        toks = tokens_of(seg)
        if any(NPM_CONFIG_ENV.search(t) for t in toks):
            return True
        if (
            toks
            and basename_cmd(toks[0]) in ENV_SETTERS
            and any("$" in t for t in toks)
        ):
            return True
    return False


def take_pkg_dir(toks: list[str]) -> tuple[list[str], str | None]:
    """패키지 매니저 바로 뒤의 디렉터리 옵션을 떼어 낸다 → (나머지 토큰, 디렉터리).

    디렉터리 옵션이 없으면 (toks, None). 판정할 수 없으면 (toks, "") — 값이 없는 옵션, 옵션이 두 번,
    서브커맨드 뒤(`--` 전)에 또 나온 옵션(`npm test --prefix x` 도 npm 은 받는다).
    """
    flags = PKG_DIR_FLAGS.get(toks[0], ()) if toks else ()

    def is_flag(t: str) -> bool:
        return t in flags or any(t.startswith(f + "=") for f in flags)

    rest, found = list(toks[1:]), None
    while rest and is_flag(rest[0]):
        if found is not None:
            return toks, ""
        head = rest[0]
        if head in flags:
            if len(rest) < 2:
                return toks, ""
            found, rest = rest[1], rest[2:]
        else:
            found, rest = head.split("=", 1)[1], rest[1:]
    before_dashes = rest[: rest.index("--")] if "--" in rest else rest
    if any(is_flag(t) for t in before_dashes):
        return toks, ""
    if found is None:
        return toks, None
    return [toks[0], *rest], found


def resolve_pkg_dir(pkg_dir: str, cwd: str) -> tuple[str, str, str]:
    """디렉터리 옵션 값 → (판정 오류 | "", 실행 디렉터리, 그 저장소 최상위).

    셸과 해석이 갈릴 수 있는 값은 거부한다 (Codex 리뷰): 비었음 · `~` 로 시작(따옴표면 셸은 펼치지 않는다) ·
    경로의 어느 성분이든 심볼릭 링크(테스트 뒤 바꿔치기). 디렉터리가 없거나 저장소가 아니어도 거부.
    """
    if not pkg_dir:
        return "pkg-dir-ambiguous", "", ""
    if pkg_dir.startswith("~"):
        return "pkg-dir-tilde", "", ""
    base = os.path.realpath(cwd or os.getcwd())
    # 경로를 적힌 그대로 한 성분씩 따라가며, 성분마다 링크가 아닌 실제 디렉터리인지 본다 — 마지막 성분만 보거나
    # 정규화 뒤 비교하면 중간 링크(`link/web`)·`..` 로 상쇄된 링크(`link/../x`, `missing/../link`)를
    # 테스트 뒤에 바꿔칠 수 있다 (Codex 리뷰 PR #49). 지나온 성분이 모두 실제 디렉터리라 `..` 는 글자대로 올라가도 된다
    cur = "/" if pkg_dir.startswith("/") else base
    for part in pkg_dir.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            cur = os.path.dirname(cur)
            continue
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            return "pkg-dir-symlink", "", ""
        if not os.path.isdir(cur):
            return "pkg-dir-missing", "", ""
    resolved = os.path.realpath(os.path.join(base, pkg_dir))
    if not os.path.isdir(resolved):
        return "pkg-dir-missing", "", ""
    top = git_toplevel(resolved)
    if not top:
        return "pkg-dir-not-repo", "", ""
    return "", resolved, top


def git_toplevel(path: str) -> str:
    """path 가 속한 저장소의 최상위 ('' = 저장소 아님)."""
    try:
        out = subprocess.run(
            ["git", "-C", path, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def check_cd_segments(
    segments: list[tuple[str, str]], cwd: str, toplevel: str
) -> tuple[str, bool]:
    """(판정 오류 | "", cd 가 있었는가). 프로젝트 루트로 가는 cd 만 허용 — 다른 저장소·하위 디렉터리(부분 실행)는 거부."""
    has_cd = False
    for _, seg in segments:
        toks = strip_wrappers(tokens_of(seg))
        if toks and basename_cmd(toks[0]) == "cd":
            has_cd = True
            target = toks[1] if len(toks) > 1 else os.path.expanduser("~")
            resolved = os.path.realpath(
                os.path.join(cwd or os.getcwd(), os.path.expanduser(target))
            )
            if not toplevel or resolved != os.path.realpath(toplevel):
                return "cd-prefix", has_cd
    return "", has_cd


def analyze_receipt(
    data: dict[str, Any], toplevel: str, test_cmd: str
) -> tuple[str, str, str]:
    """(명령, 판정, 실행 디렉터리). 실행 디렉터리는 패키지 매니저 디렉터리 옵션이 있을 때만 — 영수증은 그 저장소에 쓴다."""
    command, verdict, run_dir = _analyze_receipt(data, toplevel, test_cmd)
    return command, verdict, (run_dir if verdict == "ok" else "")


def _analyze_receipt(
    data: dict[str, Any], toplevel: str, test_cmd: str
) -> tuple[str, str, str]:
    event = data.get("hook_event_name") or "PostToolUse"
    cwd = data.get("cwd") or ""
    tool_name = data.get("tool_name") or "Bash"
    raw_input = data.get("tool_input")
    tool_input: dict[str, Any] = raw_input if isinstance(raw_input, dict) else {}
    resp = data.get("tool_response")
    if not isinstance(resp, dict):
        raw_result = data.get("tool_result")
        resp = raw_result if isinstance(raw_result, dict) else {}
    raw_command = tool_input.get("command") or ""
    command = join_lines(raw_command)
    run_dir = ""

    if event != "PostToolUse":
        return command, "not-post-tool-use", run_dir
    if tool_name != "Bash":
        return command, "not-bash", run_dir
    if resp.get("interrupted"):
        return command, "interrupted", run_dir
    if resp.get("returnCodeInterpretation"):
        return command, "nonzero-interpreted", run_dir
    if resp.get("backgroundTaskId"):
        return command, "backgrounded", run_dir
    exit_code = resp.get("exit_code")
    if exit_code is not None and str(exit_code) != "0":
        return command, "exit-%s" % exit_code, run_dir
    if not command.strip():
        return command, "empty", run_dir

    # 강화 모드: 프로젝트가 정한 정식 테스트 명령과 정확히 같아야 한다.
    # 그 명령이 디렉터리 옵션을 쓰면 영수증은 그 저장소에 쓴다
    if test_cmd:
        normalized = re.sub(r"^(rtk\s+)+", "", command.strip())
        if normalized != test_cmd.strip():
            return command, "not-test-cmd", run_dir
        segments = split_segments(normalized)
        if compound_pkg_dir(normalized, segments, raw_command):
            return command, "pkg-dir-compound", run_dir
        if sets_env_config(segments):
            return command, "pkg-env-config", run_dir
        err, has_cd = check_cd_segments(segments, cwd, toplevel)
        if err:
            return command, err, run_dir
        last = segments[-1][1] if segments else normalized
        _, pkg_dir = take_pkg_dir(strip_wrappers(tokens_of(last)))
        if pkg_dir is None and has_pkg_dir_flag(normalized, segments):
            # 옵션은 보이는데 떼어 내지 못한 형태(`-Cx`) — 실행 위치를 알 수 없다
            return command, "pkg-dir-ambiguous", run_dir
        if pkg_dir is not None:
            if has_cd:
                return command, "pkg-dir-with-cd", run_dir
            err, run_dir, _ = resolve_pkg_dir(pkg_dir, cwd)
            if err:
                return command, err, run_dir
        return command, "ok", run_dir

    if "$(" in command or "`" in command:
        return command, "indirect", run_dir
    segments = split_segments(command)
    if not segments:
        return command, "empty", run_dir
    if compound_pkg_dir(command, segments, raw_command):
        return command, "pkg-dir-compound", run_dir
    err, has_cd = check_cd_segments(segments, cwd, toplevel)
    if err:
        return command, err, run_dir
    op_before_last, last = segments[-1]
    if op_before_last in ("||", "|"):
        return command, "runner-not-guaranteed", run_dir
    raw = tokens_of(last)
    if raw == ["__UNPARSEABLE__"]:
        return command, "unparseable", run_dir
    # npm 은 npm_config_* 환경 변수도 설정(예: prefix)으로 읽는다 — 실행 위치를 분석기가 알 수 없다.
    # 앞 세그먼트의 export 도 본다 (Codex 리뷰 PR #49)
    if sets_env_config(segments):
        return command, "pkg-env-config", run_dir
    toks, pkg_dir = take_pkg_dir(strip_redirections(strip_wrappers(raw)))
    if pkg_dir is None and has_pkg_dir_flag(command, segments):
        return command, "pkg-dir-ambiguous", run_dir
    if pkg_dir is not None:
        if has_cd:
            # 상대 경로를 cd 뒤 위치로 풀어야 하는데 분석기는 hook cwd 만 안다
            return command, "pkg-dir-with-cd", run_dir
        err, run_dir, toplevel = resolve_pkg_dir(pkg_dir, cwd)
        if err:
            return command, err, run_dir
    is_runner, args, runner = match_runner(toks)
    if not is_runner:
        return command, "not-a-test", run_dir
    for k, a in enumerate(args):
        if is_excluded_arg(a, runner) or "::" in a:
            return command, "excluded-flag:%s" % a, run_dir
        if a == "-x" and k + 1 < len(args) and args[k + 1] == "test":
            return command, "excluded-flag:-x test", run_dir
        first_arg = k == 0 or (k == 1 and args[0] == "--")
        if first_arg and runner in JS_RUNNERS and a in RUNNER_SUBCOMMANDS:
            return command, "excluded-subcommand:%s" % a, run_dir
        if (
            a.startswith("/")
            and toplevel
            and not os.path.abspath(a).startswith(os.path.abspath(toplevel) + os.sep)
        ):
            return command, "outside-project", run_dir
    return command, "ok", run_dir


# ─── receipts.json ─────────────────────────────────────────────────────────

MAX_RECEIPTS = 20


def load_receipts(path: str) -> dict[str, Any]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("trees"), dict):
            return data
    except Exception:
        pass
    return {"version": 1, "trees": {}}


def receipt_has(path: str, tree: str) -> bool:
    return bool(tree) and tree in load_receipts(path)["trees"]


def receipt_latest(path: str) -> str:
    """가장 최근에 기록된 영수증 트리 ('' = 없음). 같은 초면 나중에 들어간 것."""
    trees = list(load_receipts(path)["trees"].items())
    if not trees:
        return ""
    return str(
        max(enumerate(trees), key=lambda it: (it[1][1].get("ts", ""), it[0]))[1][0]
    )


def receipt_record(path: str, tree: str, head: str, command: str) -> None:
    data = load_receipts(path)
    data["trees"][tree] = {
        "head": head,
        "command": command,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    }
    if len(data["trees"]) > MAX_RECEIPTS:
        oldest = sorted(data["trees"].items(), key=lambda kv: kv[1].get("ts", ""))[
            : len(data["trees"]) - MAX_RECEIPTS
        ]
        for k, _ in oldest:
            del data["trees"][k]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = "%s.tmp.%d" % (path, os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)


# ─── CLI ───────────────────────────────────────────────────────────────────


def _read_json_stdin() -> dict[str, Any] | None:
    try:
        data = json.load(sys.stdin)
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        return 2
    cmd = argv[1]
    if cmd == "analyze-guard":
        # fail-closed: 판정할 수 없는 입력은 허용하지 않는다 (가드가 비0 을 받으면 차단)
        data = _read_json_stdin()
        if data is None:
            print("hook input is not a JSON object", file=sys.stderr)
            return 3
        try:
            command, file_path, cwd, flags, values = analyze_guard(data)
        except Exception as exc:  # noqa: BLE001 — 어떤 분석 오류든 차단 사유로 올린다
            print("analyzer error: %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
            return 3
        print(command)
        print(file_path)
        print(cwd)
        print(" ".join(sorted(flags)))
        for key, vals in values.items():
            for v in vals:
                print("%s=%s" % (key, v))
        return 0
    if cmd == "analyze-receipt":
        data = _read_json_stdin()
        if data is None:
            return 0
        toplevel = argv[2] if len(argv) > 2 else ""
        test_cmd = argv[3] if len(argv) > 3 else ""
        command, verdict, run_dir = analyze_receipt(data, toplevel, test_cmd)
        print(command)
        print(verdict)
        print(run_dir)
        return 0
    if cmd == "receipt-has":
        return 0 if receipt_has(argv[2], argv[3]) else 1
    if cmd == "receipt-latest":
        latest = receipt_latest(argv[2])
        if not latest:
            return 1
        print(latest)
        return 0
    if cmd == "receipt-record":
        receipt_record(argv[2], argv[3], argv[4], argv[5] if len(argv) > 5 else "")
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
