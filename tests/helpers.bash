# shellcheck shell=bash
# tests/helpers.bash — bats 공용 헬퍼 (load 'helpers' 로 사용)

# REPO_ROOT: the shipped standards (templates, apply.sh) · PROJECT_ROOT: this repository (CI, renovate, scripts, tests)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT
REPO_ROOT="$PROJECT_ROOT/plugins/sos/standards"
export REPO_ROOT
HOOKS_DIR="$REPO_ROOT/common/hooks"
export HOOKS_DIR

# 임시 git 저장소를 만들고 경로를 출력한다. 커밋 하나가 들어 있다.
make_git_repo() {
    local dir
    dir="$(cd "$(mktemp -d)" && pwd -P)"   # resolved: macOS mktemp gives /var/..., a symlink to /private/var/...
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "bats"
    printf 'hello\n' > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" commit -q -m "init"
    echo "$dir"
}

# PostToolUse(Bash) 훅 입력 JSON — 실제 Claude Code(v2.1.272 스키마) 형태:
#   tool_response = {stdout, stderr, interrupted, isImage[, returnCodeInterpretation][, backgroundTaskId]}
#   exit_code 필드는 없다. 비0 종료는 PostToolUse 가 아니라 PostToolUseFailure 로 온다.
#   $1 명령, $2 interrupted(true|false), $3 (선택) tool_response 에 합칠 추가 JSON 객체
post_tool_json() {
    local extra="${3:-{\}}"
    jq -nc --arg cmd "$1" --argjson intr "$2" --argjson extra "$extra" --arg cwd "$PWD" \
        '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$cwd,
          tool_input:{command:$cmd},
          tool_response:({stdout:"",stderr:"",interrupted:$intr,isImage:false} + $extra)}'
}

# PostToolUseFailure(Bash) 훅 입력 JSON — 비0 종료·타임아웃일 때 호스트가 보내는 형태
post_tool_failure_json() {
    jq -nc --arg cmd "$1" --arg err "$2" --arg cwd "$PWD" \
        '{hook_event_name:"PostToolUseFailure",tool_name:"Bash",cwd:$cwd,
          tool_input:{command:$cmd}, error:$err}'
}

# PreToolUse(Bash) 훅 입력 JSON — $1 명령
pre_tool_json() {
    jq -nc --arg cmd "$1" --arg cwd "$PWD" \
        '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$cwd,tool_input:{command:$cmd}}'
}

# PreToolUse(Edit) 훅 입력 JSON — $1 파일 경로
pre_edit_json() {
    jq -nc --arg fp "$1" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$fp}}'
}

# In-place sed that works with GNU sed (CI) and BSD sed (macOS): BSD needs an explicit empty backup suffix.
# Replacement text must not rely on GNU-only escapes such as \n — use perl for those edits.
sed_i() {
    if sed --version >/dev/null 2>&1; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

# Real-tool tests: skip locally when the tool is missing, fail in CI (TEMPLATE_TOOLS_REQUIRED=1).
require_tool() {
    command -v "$1" >/dev/null 2>&1 && return 0
    if [ "${TEMPLATE_TOOLS_REQUIRED:-0}" = "1" ]; then
        echo "required tool missing: $1" >&2
        return 1
    fi
    skip "$1 not installed"
}
