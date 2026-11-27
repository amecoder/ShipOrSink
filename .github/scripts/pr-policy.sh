#!/usr/bin/env bash
# ============================================================================
# pr-policy.sh — PR 정책 판정 (pr-checks.yml 의 `pr-policy` job 이 호출)
# ============================================================================
# 검사 3종 — 하나라도 어기면 ::error:: 를 찍고 exit 1
#   ruleset 이 적용된 저장소(public, 또는 Pro 이상 private)에서는 이 실패가 머지를 막는다.
#   Free 플랜 private 저장소는 ruleset 을 만들 수 없어 "빨간불 안내"에 그친다 — apply-github-settings.sh 참고.
#   1. 이슈 연결  : 본문(주석·코드 펜스 제거 후)에 Closes/Fixes/Resolves #N · owner/repo#N · …/issues/N
#                   (라벨 no-issue 로 예외)
#   2. 변경 규모  : 추가+삭제 ≤ PR_MAX_LINES (기본 800), lockfile 제외 (라벨 large-pr-approved 로 예외)
#      근거: Google eng-practices "100 lines is usually a reasonable size… 1000 lines is usually too large",
#            SmartBear/Cisco 연구 "200-400 LOC" 에서 결함 발견율 최고. 800 은 AI 생성 PR 의 실무 상한으로
#            둘 사이를 택한 값 — 팀에 맞게 PR_MAX_LINES 로 낮춘다 (400 권장).
#   3. 필수 섹션  : "### 테스트 방법" 에 코드 펜스 안 실제 명령 1줄 이상, "### 롤백 계획 › 롤백 방법:" 에 내용.
#                   N/A · TBD · TODO · - · 없음 같은 자리표시자는 내용으로 치지 않는다.
#                   봇 PR(dependabot[bot] · renovate[bot], 또는 라벨 bot)은 3 을 면제한다.
#
# 입력 (환경변수):
#   PR_BODY_FILE   PR 본문을 담은 파일
#   PR_FILES_JSON  파일 배열 JSON: [{path, additions, deletions}]  (gh api …/pulls/N/files --paginate 결과)
#   PR_LABELS      쉼표 구분 라벨 (예: "ai-task,no-issue")
#   PR_AUTHOR      PR 작성자 로그인 (예: "dependabot[bot]") — 선택
#   PR_MAX_LINES   상한 (기본 800)
#
# 로컬 실행 예:
#   gh pr view 12 --json body --jq .body > /tmp/body.md
#   gh api "repos/{owner}/{repo}/pulls/12/files" --paginate --jq '[.[] | {path, additions, deletions}]' > /tmp/files.json
#   PR_BODY_FILE=/tmp/body.md PR_FILES_JSON=/tmp/files.json PR_LABELS="" bash pr-policy.sh
# 의존: bash · jq · awk
# ============================================================================
set -euo pipefail

: "${PR_BODY_FILE:?PR_BODY_FILE 이 필요합니다}"
: "${PR_FILES_JSON:?PR_FILES_JSON 이 필요합니다}"
PR_LABELS="${PR_LABELS:-}"
PR_AUTHOR="${PR_AUTHOR:-}"
PR_MAX_LINES="${PR_MAX_LINES:-800}"

FAILED=0
fail() { echo "::error::$1"; FAILED=1; }
pass() { echo "::notice::$1"; }
has_label() { [[ ",${PR_LABELS// /}," == *",$1,"* ]]; }
is_bot() { has_label bot || [[ "$PR_AUTHOR" == *"[bot]" ]]; }

# ─── 본문 정규화: CRLF 제거 · HTML 주석 제거 · 코드 펜스는 별도 처리 ───────
# strip_comments: <!-- … --> (여러 줄 포함) 제거
strip_comments() {
    awk '
    { line = $0; out = ""
      while (1) {
        if (inc) { i = index(line, "-->"); if (i) { line = substr(line, i + 3); inc = 0 } else { line = ""; break } }
        else     { i = index(line, "<!--"); if (i) { out = out substr(line, 1, i - 1); line = substr(line, i + 4); inc = 1 } else { out = out line; break } }
      }
      print out }'
}
# strip_fences: ``` … ``` 블록 전체 제거 (이슈 연결 검사용 — 펜스 안의 "Closes #1" 은 인정하지 않는다)
strip_fences() {
    awk '/^[[:space:]]*(```|~~~)/ { inf = !inf; next } !inf { print }'
}

CLEAN="$(mktemp)"; NOFENCE="$(mktemp)"
trap 'rm -f "$CLEAN" "$NOFENCE"' EXIT
tr -d '\r' < "$PR_BODY_FILE" | strip_comments > "$CLEAN"
strip_fences < "$CLEAN" > "$NOFENCE"

# ─── 1. 이슈 연결 ───────────────────────────────────────────────────────
ISSUE_RE='(^|[[:space:](,;])(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]*:?[[:space:]]*(([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[1-9][0-9]*|https?://[^[:space:]]+/issues/[1-9][0-9]*)'
if has_label no-issue; then
    pass "이슈 연결 검사 건너뜀 (라벨 no-issue)"
elif grep -qiE "$ISSUE_RE" "$NOFENCE"; then
    pass "이슈 연결 확인"
else
    fail "이슈 연결 없음 — 본문에 'Closes #<번호>' (또는 Fixes/Resolves, owner/repo#N, 이슈 URL) 를 적거나, 이슈가 정말 없으면 라벨 no-issue 를 붙이세요 (주석·코드 펜스 안은 인정하지 않습니다)"
fi

# ─── 2. 변경 규모 ───────────────────────────────────────────────────────
# lockfile 은 루트 또는 워크스페이스 디렉터리(packages/<name>/ 등 최대 2단계)에 있는 것만 제외한다
LOCKFILE_RE='^([^/]+/){0,2}(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Cargo\.lock|go\.sum|poetry\.lock|uv\.lock|Pipfile\.lock|Gemfile\.lock|Podfile\.lock|pubspec\.lock|packages\.lock\.json|composer\.lock|flake\.lock)$'
SNAPSHOT_RE='\.snap$'
SNAPSHOT_MAX=2000
if has_label large-pr-approved; then
    pass "변경 규모 검사 건너뜀 (라벨 large-pr-approved)"
else
    CHANGED=$(jq --arg re "$LOCKFILE_RE" --arg snap "$SNAPSHOT_RE" \
        '[.[] | select((.path | test($re) | not) and (.path | test($snap) | not))
              | (((.additions // 0) | tonumber? // 0) + ((.deletions // 0) | tonumber? // 0)) | select(. >= 0)] | add // 0' \
        "$PR_FILES_JSON")
    SNAP_CHANGED=$(jq --arg snap "$SNAPSHOT_RE" \
        '[.[] | select(.path | test($snap)) | (((.additions // 0) | tonumber? // 0) + ((.deletions // 0) | tonumber? // 0))] | add // 0' \
        "$PR_FILES_JSON")
    if (( CHANGED > PR_MAX_LINES )); then
        fail "변경 ${CHANGED}줄 > 상한 ${PR_MAX_LINES}줄 (lockfile·스냅샷 제외) — PR 을 나누거나, 리뷰어가 라벨 large-pr-approved 를 붙이세요"
    elif (( SNAP_CHANGED > SNAPSHOT_MAX )); then
        fail "스냅샷(.snap) 변경 ${SNAP_CHANGED}줄 > ${SNAPSHOT_MAX}줄 — 스냅샷 갱신을 별도 PR 로 나누거나 라벨 large-pr-approved"
    else
        pass "변경 규모 ${CHANGED}줄 ≤ ${PR_MAX_LINES}줄 (스냅샷 ${SNAP_CHANGED}줄)"
    fi
fi

# ─── 3. 필수 섹션 ───────────────────────────────────────────────────────
# "### <제목>" 아래부터 다음 제목(#·##·###) 전까지 — 코드 펜스 안의 '#' 줄은 제목으로 보지 않는다
section() {
    awk -v h="$2" '
        /^[[:space:]]*(```|~~~)/ { if (p) print; inf = !inf; next }
        !inf && $0 ~ ("^###[[:space:]]+" h "[[:space:]]*$") { p = 1; next }
        !inf && p && /^#{1,3}[[:space:]]/ { p = 0 }
        p { print }' "$1"
}
# 코드 펜스 안의 줄만 (펜스 마커 제외)
fenced_lines() {
    awk '/^[[:space:]]*(```|~~~)/ { inf = !inf; next } inf { print }'
}
PLACEHOLDER_RE='^[[:space:]]*(N/?A|TBD|TODO|-+|\.+|없음|해당[[:space:]]*없음|나중에|\[[ x]\].*)?[[:space:]]*$'
TEMPLATE_RE='^[[:space:]]*(#[[:space:]]*테스트 실행 커맨드|커버리지:[[:space:]]*_+[[:space:]]*%?)[[:space:]]*$'

if is_bot; then
    pass "필수 섹션 검사 건너뜀 (봇 PR: ${PR_AUTHOR:-label bot})"
else
    # 3a. 테스트 방법 — 코드 펜스 안에 주석·자리표시자가 아닌 실제 명령이 1줄 이상
    TEST_CMDS=$(section "$CLEAN" "테스트 방법" | fenced_lines \
        | grep -vE "$TEMPLATE_RE" | grep -vE '^[[:space:]]*(#|$)' | grep -cvE "$PLACEHOLDER_RE" || true)
    if (( TEST_CMDS > 0 )); then
        pass "'테스트 방법' 섹션 작성 확인 (명령 ${TEST_CMDS}줄)"
    else
        fail "'### 테스트 방법' 섹션을 찾지 못했거나 코드 펜스 안에 실제 명령이 없습니다 — 제목은 정확히 '### 테스트 방법', 리뷰어가 재현할 명령을 \`\`\`bash 펜스 안에 적으세요 (N/A·TBD 는 내용이 아닙니다)"
    fi

    # 3b. 롤백 계획 — "롤백 방법:" 뒤에 자리표시자가 아닌 내용
    ROLLBACK=$(section "$CLEAN" "롤백 계획" | grep -E '^[[:space:]]*-?[[:space:]]*\**롤백 방법\**[[:space:]]*[:：]' | head -1 | sed -E 's/^[^:：]*[:：][[:space:]]*//' || true)
    if [[ -n "$ROLLBACK" ]] && ! grep -qE "$PLACEHOLDER_RE" <<< "$ROLLBACK"; then
        pass "'롤백 계획' 작성 확인"
    else
        fail "'### 롤백 계획' 의 '롤백 방법:' 을 찾지 못했거나 비어 있습니다 — 이 변경이 실패하면 어떻게 되돌리는지 적으세요 (N/A·- 는 내용이 아닙니다)"
    fi
fi

exit "$FAILED"
