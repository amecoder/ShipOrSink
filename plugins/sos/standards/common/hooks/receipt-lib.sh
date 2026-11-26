#!/bin/bash
# receipt-lib.sh — 테스트 영수증 공용 함수 (bash 쪽)
# test-receipt.sh(PostToolUse)와 pre-tool-use-guard.sh(PreToolUse)가 source 한다.
# 명령 분석·영수증 파일 입출력은 같은 디렉터리의 hooklib.py 가 맡는다.
#
# 영수증 = "이 작업 트리 내용으로 테스트가 통과했다"는 호스트 이벤트 기록.
# 위치: <git common dir>/claude/receipts.json  (.git 안 — 트리 해시에 절대 섞이지 않고,
#        worktree 여러 개가 같은 저장소의 영수증을 공유한다. .gitignore 에 의존하지 않는다)
#
# 정직한 한계: 같은 사용자 권한의 Bash 가 있으면 영수증도 훅도 원리적으로 고칠 수 있다.
# 이 장치는 "게으른 우회"를 비싸게 만드는 가드레일이고, 진짜 강제는 서버측 ruleset + CI 다.

HOOKLIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hooklib.py"

# 저장소 최상위 — $1 은 훅 입력의 cwd (없으면 CLAUDE_PROJECT_DIR, 그것도 없으면 pwd)
receipt_toplevel() {
  local start="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  git -C "$start" rev-parse --show-toplevel 2>/dev/null
}

# 영수증 파일 경로 — 저장소가 아니면 빈 문자열
receipt_path() {
  local start="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}" common
  common="$(git -C "$start" rev-parse --git-common-dir 2>/dev/null)" || return 1
  [[ "$common" != /* ]] && common="$(cd "$start" && cd "$common" && pwd)"
  printf '%s/claude/receipts.json\n' "$common"
}

# 차단 기록 — <git common dir>/claude/blocks.jsonl 에 {ts, reason, command} 한 줄.
# 자기 사용으로 "가드가 실제로 몇 번 막았나"를 세기 위한 관측 장치라 fail-open: 어떤 실패도 판정에 영향이 없다.
# $1 reason · $2 command (200자로 자른다) · $3 훅 입력의 cwd
receipt_log_block() {
  local file
  file="$(receipt_path "${3:-}" 2>/dev/null)" || return 0
  [[ -n "$file" ]] || return 0
  file="${file%/receipts.json}/blocks.jsonl"
  mkdir -p "$(dirname "$file")" 2>/dev/null || return 0
  python3 -c 'import json, sys, datetime
print(json.dumps({"ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                  "reason": sys.argv[1], "command": sys.argv[2][:200]}, ensure_ascii=False))' \
    "$1" "${2:-}" >> "$file" 2>/dev/null || true
  return 0
}

# 작업 트리 내용 해시.
# 임시 index 에 `git add -A` 한 뒤 `git write-tree` 하면 "지금 디스크에 있는 내용"의 트리 객체 ID가 나온다.
# - HEAD·staging 상태와 무관하다 (커밋 전/후, add 전/후 모두 같은 값)
# - .gitignore 를 존중한다
# - 변경을 전부 커밋하면 `git rev-parse HEAD^{tree}` 와 정확히 같아진다
working_tree_hash() {
  local start="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}" root tmp_index idx rc
  root="$(receipt_toplevel "$start")" || return 1
  [[ -n "$root" ]] || return 1

  tmp_index="$(mktemp)"
  # 기존 index 를 복사해 두면 add -A 가 증분으로 빠르게 끝난다 (worktree 는 절대 경로를 돌려준다)
  idx="$(git -C "$root" rev-parse --git-path index)"
  [[ "$idx" != /* ]] && idx="$root/$idx"
  cp "$idx" "$tmp_index" 2>/dev/null || true

  GIT_INDEX_FILE="$tmp_index" git -C "$root" add -A -- . 2>/dev/null &&
    GIT_INDEX_FILE="$tmp_index" git -C "$root" write-tree
  rc=$?
  rm -f "$tmp_index" "$tmp_index.lock"
  return $rc
}

# 커밋된 HEAD 의 트리 ID (저장소가 아니면 빈 문자열)
head_tree_hash() {
  git -C "${1:-${CLAUDE_PROJECT_DIR:-$PWD}}" rev-parse 'HEAD^{tree}' 2>/dev/null || true
}

# 임의 ref 의 트리 ID — $1 저장소 위치, $2 ref (브랜치·태그·SHA·HEAD)
ref_tree_hash() {
  git -C "$1" rev-parse --verify --quiet "$2^{tree}" 2>/dev/null || true
}

# 영수증에 이 트리가 있는가 — $1 저장소 위치, $2 tree
receipt_has_tree() {
  local path
  path="$(receipt_path "$1")" || return 1
  python3 "$HOOKLIB" receipt-has "$path" "$2"
}

# 영수증이 없을 때의 진단 — $1 저장소 위치, $2 push 되는 tree.
# 가장 최근 영수증 트리와 push 트리의 차이 파일(최대 10줄)과 .gitignore 힌트를 줄바꿈으로 시작해 출력한다.
# 흔한 원인: 테스트가 만든 coverage/ 같은 미추적 산출물이 영수증 트리에는 들어가고 커밋에는 빠진 경우.
receipt_miss_hint() {
  local path latest diff
  path="$(receipt_path "$1")" || return 0
  latest="$(python3 "$HOOKLIB" receipt-latest "$path" 2>/dev/null)" || return 0
  [[ -n "$latest" ]] || return 0
  diff="$(git -C "$1" diff-tree -r --name-status "$latest" "$2" 2>/dev/null | head -10)"
  [[ -n "$diff" ]] || return 0
  printf '\n  files differing from the most recent receipt tree (%s, first 10):\n' "${latest:0:12}"
  printf '%s\n' "$diff" | sed 's/^/    /'
  printf '  hint: if these are generated test artifacts (coverage/, .pytest_cache/, test-results/ …), add them to .gitignore and re-run the tests'
}

# 영수증 기록 — $1 저장소 위치, $2 tree, $3 head, $4 command
receipt_record() {
  local path
  path="$(receipt_path "$1")" || return 1
  python3 "$HOOKLIB" receipt-record "$path" "$2" "$3" "$4"
}
