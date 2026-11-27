#!/bin/bash
# Claude Code PostToolUse Hook (matcher: Bash) — 테스트 영수증 기록
#
# Bash 도구가 실행한 명령이 "테스트 러너"이고 성공으로 끝났으면
# <git common dir>/claude/receipts.json 에 현재 작업 트리 해시를 적는다.
# pre-tool-use-guard.sh 는 git push / gh pr create 직전에 push 되는 트리가 이 영수증에 있는지 대조한다.
#
# "성공" 판정 (Claude Code v2.1.272 실측 스키마 — tool_response 에 exit_code 는 없다):
#   - 이 훅은 PostToolUse 에서만 발화한다. 비0 종료·타임아웃은 PostToolUseFailure 로 가므로 애초에 오지 않는다.
#   - tool_response = {stdout, stderr, interrupted, isImage[, returnCodeInterpretation][, backgroundTaskId]}
#     interrupted=true            → 중단됨, 스킵
#     returnCodeInterpretation    → "의미 있는 비0 종료"(grep 무매치 등), 스킵
#     backgroundTaskId            → 백그라운드로 넘어가 아직 안 끝남, 스킵
#     exit_code (구버전·타 호스트) → 있으면 0 일 때만 통과
#
# "테스트 러너" 판정 (hooklib.py analyze-receipt — 토큰 분석):
#   - 러너가 명령 체인의 **마지막** 세그먼트여야 한다: `pytest; true`·`pytest || true`·`pytest | tail` 은 거부
#   - 러너 앞 연산자가 `||`·`|` 면 거부 (러너가 실행됐다는 보장이 없다)
#   - `cd …` 가 앞에 있으면 거부, 프로젝트 밖 절대 경로 인자는 거부
#   - 테스트를 안 돌리거나 일부만 고르는 옵션(--version --help --collect-only --dry-run -DskipTests -x test
#     --list* --passWithNoTests -k -m -run --testPathPattern -t --filter --grep, `::` 선택자)은 거부
#   - 래퍼 허용: rtk · env · uv run · poetry run · pipenv run · bundle exec · npx · pnpm exec · timeout N
#   - 패키지 매니저 디렉터리 옵션(pnpm -C/--dir · npm --prefix · yarn/bun --cwd): 그 디렉터리가 속한 저장소에 기록한다
#     (모노레포 하위 패키지 · 다른 저장소 클론). 디렉터리가 없거나 저장소가 아니면 거부
#   - 강화 모드: .claude/settings.json 의 env TEST_CMD 가 있으면 그 명령과 정확히 같을 때만 인정
#
# 언제나 exit 0 (fail-open): 영수증을 못 써도 작업을 막지 않는다. 막는 쪽은 가드다.
#
# Usage in .claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/test-receipt.sh"}]
#     }]
#   }
# }

# shellcheck source=SCRIPTDIR/receipt-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/receipt-lib.sh"

INPUT=$(cat)
command -v python3 >/dev/null 2>&1 || exit 0

# 훅 입력의 cwd 가 기준 저장소 — worktree 세션에서도 그 worktree 를 본다
CWD=$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin).get("cwd") or "")
except Exception:
    print("")')
[[ -n "$CWD" && -d "$CWD" ]] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

TOPLEVEL=$(receipt_toplevel "$CWD") || exit 0
[[ -n "$TOPLEVEL" ]] || exit 0

PARSED=$(printf '%s' "$INPUT" | python3 "$HOOKLIB" analyze-receipt "$TOPLEVEL" "${TEST_CMD:-}") || exit 0
COMMAND=$(printf '%s\n' "$PARSED" | sed -n '1p')
VERDICT=$(printf '%s\n' "$PARSED" | sed -n '2p')
RUN_DIR=$(printf '%s\n' "$PARSED" | sed -n '3p')

[[ -n "$COMMAND" ]] || exit 0
[[ "$VERDICT" == "ok" ]] || exit 0

# `pnpm -C <dir> test` 처럼 실행 디렉터리를 지정했으면 그 디렉터리가 속한 저장소에 기록한다 (다른 저장소 클론 포함)
if [[ -n "$RUN_DIR" ]]; then
  CWD="$RUN_DIR"
  TOPLEVEL=$(receipt_toplevel "$CWD") || exit 0
  [[ -n "$TOPLEVEL" ]] || exit 0
fi

# --- 영수증 기록 ---
TREE=$(working_tree_hash "$CWD") || exit 0
[[ -n "$TREE" ]] || exit 0
receipt_record "$CWD" "$TREE" "$(head_tree_hash "$CWD")" "$COMMAND" 2>/dev/null || true

# 미추적 파일(무시되지 않은 것)도 영수증 트리에 들어간다 — 커밋하지 않으면 push 트리와 어긋난다.
# PostToolUse 의 stderr 는 모델에게 가지 않으므로 additionalContext(JSON stdout)로 알린다.
UNTRACKED=$(git -C "$TOPLEVEL" ls-files --others --exclude-standard 2>/dev/null)
if [[ -n "$UNTRACKED" ]]; then
  COUNT=$(printf '%s\n' "$UNTRACKED" | wc -l | tr -d ' ')
  SAMPLE=$(printf '%s\n' "$UNTRACKED" | head -5 | paste -sd ',' - | sed 's/,/, /g')
  MSG="test receipt recorded, but $COUNT untracked file(s) are included in the receipt tree ($SAMPLE). Commit them, or add generated artifacts (coverage/, .pytest_cache/ …) to .gitignore and re-run the tests — otherwise the pushed tree will not match the receipt."
  python3 -c 'import json, sys
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": sys.argv[1]}}))' "$MSG" || true
fi
exit 0
