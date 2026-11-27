#!/bin/bash
# Claude Code PreToolUse Hook — Dangerous command blocker + test receipt gate
# Exit 2 = block the action. Exit 0 = allow.
#
# 판정은 정규식이 아니라 토큰 분석(hooklib.py analyze-guard, shlex)으로 한다:
#   `git "push"` · `git p''ush` · `\git push` · `command git push` · `env X=1 git push` ·
#   `timeout 60 git push` · `git -C dir push` · `gh pr new` · `gh -R o/r pr create` · `gh api …/pulls -X POST`
#   처럼 문자열은 달라도 셸이 실행하는 것이 같으면 같게 본다.
#   여러 줄 명령은 한 줄로 합쳐 둘째 줄 이후도 본다. 읽기 전용 quick-exit 는 연산자가 없는 단순 명령에만.
#
# 차단 목록
#   - git push --force / -f / +refspec (--force-with-lease 는 허용) · main/master 로 향하는 push (refspec 대상 포함,
#     인자 없는 `git push` 는 현재 브랜치가 main 이면 차단) · --all / --mirror
#   - git reset --hard · rm -rf 루트/홈/상위(-fr, -r -f, --no-preserve-root 변형 포함) · DROP DATABASE/TABLE/SCHEMA
#   - terraform destroy -auto-approve · kubectl delete namespace
#   - .env* 파일을 인자로 받는 모든 Bash 명령 (.env.example 류 제외) · .env/.pem/.key/credentials 편집
#   - 훅·설정·영수증 파일(.claude/hooks, .claude/settings*.json, claude/receipts)의 편집·쓰기·리다이렉션
#   - 위임 실행(sh -c · bash -c · eval · xargs · $( ) · alias) 안에 push/PR 문자열이 있으면 무조건 차단 (fail-closed)
#   - 스크립트 파일(bash f · sh f · ./f · source f · bash < f · bash 0< f, 중첩 3단계 · 파일 64개까지)은 본문을
#     같은 규칙으로 판정한다 — main push · 영수증 게이트 · 위임 실행 · ap 라벨. 예약어(if/then · { } · ( ) · do ·
#     case · 함수) 뒤의 명령도 본다. ./f 는 셸 셰뱅 또는 셰뱅 없는 텍스트일 때만(bats 등 다른 실행기는 따라가지 않는다).
#     python·node 등 파일은 git push · gh pr create · gh api …/pulls · gh … ap:* 가 문자열·리스트 리터럴로 붙어 있고
#     프로세스 API 가 함께 있거나, /pulls 가 네트워크 호출과 함께 있으면 차단(문서 편집 글자는 통과).
#     `… | bash` · `bash <(…)` · FIFO·장치 입력은 차단. 1MB 넘는 스크립트는 바이너리 구간 전까지 push 단어만 훑는다.
#     실행 중에 조립되는 문자열은 보지 못한다 — 최종 근거는 서버 기록(autopilot 우회 점검 · signals)
#   - ap:* 라벨(사람만 단다): gh pr/issue create --label · edit 달기·떼기 · gh label create/edit/delete · gh api 쓰기
#     (이름 · %3a 인코딩 · --input/-F @파일 내용 · 목록 교체 PUT · 전부 삭제 · 이슈 PATCH labels · GraphQL 라벨 변경)
#   - 테스트 영수증 게이트: git push / gh pr create 가 보내는 커밋의 트리가 영수증에 없으면 차단.
#     삭제·태그 전용 push, --help, --dry-run 은 면제. TEST_RECEIPT_REQUIRED=0 (settings env, 사람이 결정) 이면 게이트 생략.
#
# fail-closed: python3 가 없거나 실행되지 않으면(스텁), 또는 분석기가 실패하거나 입력이 JSON 객체가 아니면
#   판정이 불가능하므로 exit 2 ("guard analyzer failed"). 형식이 올바른 무관한 이벤트는 허용한다.
# 인자 없는 push 와 refspec 의 HEAD·@ 는 (-C 를 존중해) 현재 브랜치로 풀어 main/master 를 판정한다.
# .env 는 실제로 여는 인자만 본다 — grep 패턴·git check-ignore·ls·test 처럼 이름만 참조하는 것은 허용.
#
# Usage in .claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash|Edit|Write",
#       "hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-tool-use-guard.sh"}]
#     }]
#   }
# }

# shellcheck source=SCRIPTDIR/receipt-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/receipt-lib.sh"

INPUT=$(cat)

# `command -v` 만으로는 부족하다 — Xcode CLT 없는 macOS 의 /usr/bin/python3 는 존재하지만 실행되지 않는 스텁이다
if ! python3 -c 'import shlex, json' >/dev/null 2>&1; then
  echo "Blocked: a working python3 is required by pre-tool-use-guard.sh (install python3 or remove the hook deliberately)" >&2
  exit 2
fi

ANALYZER_ERR="$(mktemp)"
if ! PARSED=$(printf '%s' "$INPUT" | python3 "$HOOKLIB" analyze-guard 2>"$ANALYZER_ERR"); then
  echo "Blocked: guard analyzer failed — refusing to allow an unanalyzed tool call ($(head -c 300 "$ANALYZER_ERR"))" >&2
  rm -f "$ANALYZER_ERR"
  exit 2
fi
rm -f "$ANALYZER_ERR"
COMMAND=$(printf '%s\n' "$PARSED" | sed -n '1p')
FILE_PATH=$(printf '%s\n' "$PARSED" | sed -n '2p')
CWD=$(printf '%s\n' "$PARSED" | sed -n '3p')
FLAGS=" $(printf '%s\n' "$PARSED" | sed -n '4p') "
VALUES=$(printf '%s\n' "$PARSED" | sed -n '5,$p')

has_flag() { [[ "$FLAGS" == *" $1 "* ]]; }
values_of() { printf '%s\n' "$VALUES" | sed -n "s/^$1=//p"; }
block() { receipt_log_block "$1" "${COMMAND:-$FILE_PATH}" "$CWD"; echo "Blocked: $1" >&2; exit 2; }

# --- Bash commands ---
if [[ -n "$COMMAND" ]]; then
  # 훅·설정·영수증 파일 보호와 .env 는 quick-exit 보다 먼저 본다
  has_flag SENSITIVE_PATH && block "modifying Claude Code hooks/settings/receipts from a tool call is not allowed (edit them outside the session)"
  has_flag ENVFILE && block ".env files may not be read or written by tool calls (use .env.example)"

  # 연산자 없는 단순 읽기 전용 명령은 여기서 끝
  has_flag SIMPLE_READ_ONLY && exit 0

  COMMAND_UPPER=$(printf '%s' "$COMMAND" | tr '[:lower:]' '[:upper:]')

  # 위임 실행 안의 push/PR — 내용을 볼 수 없으므로 차단
  has_flag INDIRECT && block "push / PR creation through an indirect shell (sh -c, eval, xargs, \$( ), alias, a script file that cannot be read) — run the git/gh command directly"

  # ap:* 라벨(판정 채점 · 심각 결함 ap:s0/ap:s1)은 사람만 단다 — 달기 · 떼기 · 라벨 목록 교체
  has_flag APLABEL && block "ap:* labels are human-only (scoring and severe-defect labels) — ask the user to add or remove them"

  # Destructive
  has_flag RMRF && block "rm -rf on root/home/parent directory"
  [[ "$COMMAND" =~ git[[:space:]]+(-[^[:space:]]+[[:space:]]+)*reset[[:space:]]+--hard ]] && block "git reset --hard (potential data loss)"
  [[ "$COMMAND_UPPER" =~ DROP[[:space:]]+(DATABASE|TABLE|SCHEMA) ]] && block "DROP DATABASE/TABLE/SCHEMA"
  [[ "$COMMAND" =~ terraform[[:space:]]+destroy.*-?-auto-approve ]] && block "terraform destroy with auto-approve"
  [[ "$COMMAND" =~ kubectl[[:space:]]+delete[[:space:]]+(namespace|ns)([[:space:]]|$) ]] && block "kubectl delete namespace"

  # git push policy
  if has_flag PUSH; then
    has_flag FORCE && block "git push --force (use --force-with-lease only when approved)"
    has_flag MAIN && block "push to main/master (use a PR)"
    has_flag ALL && block "git push --all/--mirror (push one branch at a time)"
    if has_flag NOREFSPEC && ! has_flag HELP && ! has_flag DRYRUN; then
      REPO_DIR="$(values_of GITDIR | head -1)"; [[ -n "$REPO_DIR" ]] || REPO_DIR="${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"
      CURRENT_BRANCH="$(git -C "$REPO_DIR" symbolic-ref --short HEAD 2>/dev/null || true)"
      [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]] && block "push to $CURRENT_BRANCH (use a PR)"
    fi
  fi

  # --- Test receipt gate: the pushed tree must have a passing test receipt ---
  if (has_flag PUSH || has_flag PRCREATE) && ! has_flag HELP && ! has_flag DRYRUN && [[ "${TEST_RECEIPT_REQUIRED:-1}" != "0" ]]; then
    if has_flag PUSH && has_flag DELETE && [[ -z "$(values_of SRC)" ]]; then
      :  # 브랜치 삭제만 — 보낼 트리가 없다
    elif has_flag TAGS && [[ -z "$(values_of SRC)" ]]; then
      :  # --tags 만 — 태그는 트리가 아니다
    else
      REPO_DIR="$(values_of GITDIR | head -1)"; [[ -n "$REPO_DIR" ]] || REPO_DIR="${CWD:-${CLAUDE_PROJECT_DIR:-$PWD}}"
      receipt_path "$REPO_DIR" >/dev/null 2>&1 || block "not a git repository — cannot verify tests for this push"
      SRCS="$(values_of SRC)"; [[ -n "$SRCS" ]] || SRCS="HEAD"
      while IFS= read -r src; do
        [[ -n "$src" ]] || continue
        TREE="$(ref_tree_hash "$REPO_DIR" "$src")"
        [[ -n "$TREE" ]] || block "cannot resolve '$src' in $REPO_DIR — push a ref that exists locally"
        receipt_has_tree "$REPO_DIR" "$TREE" \
          || block "no passing test receipt for the tree being pushed ($src → ${TREE:0:12}) — run the project's test suite on this exact code, commit, then push$(receipt_miss_hint "$REPO_DIR" "$TREE")"
      done <<< "$SRCS"
    fi
  fi
fi

# --- Protected file patterns (Edit / Write) ---
if [[ -n "$FILE_PATH" ]]; then
  BASENAME="${FILE_PATH##*/}"
  case "$BASENAME" in
    .env.example | .env.sample | .env.template | *.env.example | *.env.sample | *.env.template) exit 0 ;;
    .env | .env.* | *.env)
      # README.env.md 처럼 문서 확장자로 끝나는 것은 시크릿 파일이 아니다
      [[ "$BASENAME" =~ \.(md|txt|rst)$ ]] || block "editing .env files (use .env.example)" ;;
    *.pem | *.key | *.secret | *credentials*) block "editing secrets/credentials files" ;;
  esac
  case "$FILE_PATH" in
    */.claude/hooks/* | .claude/hooks/* | */.claude/settings.json | .claude/settings.json | \
    */.claude/settings.local.json | .claude/settings.local.json | */claude/receipts* | */.claude/receipts/*)
      block "editing Claude Code hooks/settings/receipts from a tool call (edit them outside the session)" ;;
  esac
fi

exit 0
