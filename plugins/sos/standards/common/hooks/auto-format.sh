#!/bin/bash
# Claude Code PostToolUse Hook — Multi-language auto-formatter
# Triggered after Edit/Write operations to auto-format saved files.
#
# Performance optimizations:
#   - Python stdlib JSON parsing only (no jq dependency)
#   - 50KB 초과 파일 스킵 (대형 파일 포맷팅 방지)
#   - SQL/YAML은 pre-commit에서만 실행 (느린 도구 제외)
#   - 로컬 설치 도구만 실행 (./node_modules/.bin · pnpm/yarn exec · PATH) — bunx/npx 레지스트리 다운로드 금지
#
# Usage in .claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Edit|Write",
#       "hooks": [{"type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/auto-format.sh"}]
#     }]
#   }
# }

INPUT=$(cat)

# --- JSON parsing without jq ---
if command -v python3 >/dev/null 2>&1; then
  FILE=$(printf '%s' "$INPUT" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
for key in ("file_path", "path"):
    value = tool_input.get(key) or data.get(key)
    if isinstance(value, str):
        print(value)
        break
')
else
  FILE=""
fi

[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# --- Skip large files (>50KB) to avoid slow formatting ---
FILE_SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null || echo 0)
[[ "$FILE_SIZE" -gt 51200 ]] && exit 0

# 이미 설치된 도구만 실행한다. 레지스트리에서 받아 실행하는 경로(bunx · npx · pnpm dlx)는 쓰지 않는다 —
# 예: `bunx biome` 은 공식 @biomejs/biome 이 아니라 npm 의 다른 패키지 `biome` 을 받아 돌린다.
# bun 프로젝트도 `bun install` 이 ./node_modules/.bin 에 도구를 두므로 첫 분기에서 잡힌다.
# 반환: 도구 종료 코드, 설치돼 있지 않으면 127.
run_local_tool() {
  local tool="$1"
  shift

  if [[ -x "./node_modules/.bin/$tool" ]]; then
    "./node_modules/.bin/$tool" "$@"
    return $?
  fi

  # pnpm exec / yarn exec 는 로컬 의존성의 bin 만 찾는다 (다운로드하지 않는다)
  if [[ -f "pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
    pnpm exec "$tool" "$@"
    return $?
  fi

  if [[ -f "yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
    yarn exec "$tool" "$@"
    return $?
  fi

  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@"
    return $?
  fi

  return 127
}

case "$FILE" in
  *.py)
    command -v ruff >/dev/null 2>&1 && ruff format --quiet "$FILE" 2>/dev/null
    ;;
  *.kt | *.kts)
    # ktlint is fast when Gradle daemon is warm (~300ms)
    command -v ktlint >/dev/null 2>&1 && ktlint --format "$FILE" 2>/dev/null
    ;;
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs)
    # Prefer biome when the project has it; otherwise use local Prettier.
    run_local_tool biome format --write "$FILE" 2>/dev/null
    BIOME_RC=$?
    PRETTIER_RC=0
    if [[ $BIOME_RC -ne 0 ]]; then
      run_local_tool prettier --write "$FILE" 2>/dev/null
      PRETTIER_RC=$?
    fi
    if [[ $BIOME_RC -eq 127 && $PRETTIER_RC -eq 127 ]]; then
      echo "auto-format: biome/prettier not installed locally — skipped (install as a devDependency; registry downloads are not used)" >&2
    fi
    ;;
  *.go)
    command -v gofumpt >/dev/null 2>&1 && gofumpt -w "$FILE" 2>/dev/null
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" 2>/dev/null
    ;;
  *.swift)
    command -v swiftformat >/dev/null 2>&1 && swiftformat "$FILE" 2>/dev/null
    ;;
  *.java)
    command -v google-java-format >/dev/null 2>&1 && google-java-format -i "$FILE" 2>/dev/null
    ;;
  *.dart)
    command -v dart >/dev/null 2>&1 && dart format "$FILE" 2>/dev/null
    ;;
  *.tf)
    command -v terraform >/dev/null 2>&1 && terraform fmt "$FILE" 2>/dev/null
    ;;
  # SQL and YAML: skip on edit, run in pre-commit only (slow tools)
  # *.sql → sqlfluff fix (200-500ms, too slow for per-edit)
  # *.yml → prettier (100-200ms, run in pre-commit)
esac

exit 0
