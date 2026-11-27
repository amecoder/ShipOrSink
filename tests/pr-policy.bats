#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# pr-policy.sh — PR 본문·라벨·변경 규모 판정 계약
#   입력: PR_BODY_FILE(본문) · PR_LABELS(쉼표) · PR_FILES_JSON([{path,additions,deletions}]) · PR_AUTHOR(선택)
#   출력: 위반마다 ::error:: 한 줄, 하나라도 있으면 exit 1

load 'helpers'

POLICY="$REPO_ROOT/common/github-templates/scripts/pr-policy.sh"

setup() {
    WORK="$(mktemp -d)"
    export PR_BODY_FILE="$WORK/body.md"
    export PR_FILES_JSON="$WORK/files.json"
    export PR_LABELS=""
    export PR_AUTHOR="alice"
    export PR_MAX_LINES=800
    good_body > "$PR_BODY_FILE"
    files_json 'src/a.ts' 10 5 > "$PR_FILES_JSON"
}

teardown() { rm -rf "$WORK"; }

# 템플릿을 성실히 채운 본문 — 펜스 안에 템플릿 주석 줄이 남아 있어도 통과해야 한다
good_body() {
    cat <<'BODY'
## 요약
로그인 실패 시 재시도 버튼 추가

## 테스트

### 테스트 방법
<!-- 리뷰어가 검증할 수 있도록 테스트 절차와 결과를 기술 -->
```bash
# 테스트 실행 커맨드
pnpm test -- auth   # 42 passed
```
<!-- 커버리지: 84% -->

## 운영 안전성

### 롤백 계획
- 롤백 방법: 이 PR 을 revert 한다
- 영향 범위: 로그인 화면

## 관련 이슈
Closes #42
BODY
}

files_json() {
    local out="[]"
    while [[ $# -ge 3 ]]; do
        out="$(jq -c --arg p "$1" --argjson a "$2" --argjson d "$3" '. + [{path:$p,additions:$a,deletions:$d}]' <<< "$out")"
        shift 3
    done
    echo "$out"
}

@test "policy: 성실히 채운 PR 은 통과 (펜스 안 템플릿 주석이 남아 있어도)" {
    run bash "$POLICY"
    [ "$status" -eq 0 ]
}

@test "policy: Closes #N 이 없으면 실패하고 이유를 출력" {
    sed -i.bak '/Closes #42/d' "$PR_BODY_FILE"
    run bash "$POLICY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"::error::"* ]]
    [[ "$output" == *"Closes"* ]]
}

@test "policy: Fixes / Resolves / owner/repo#N / 이슈 URL 도 이슈 연결로 인정" {
    for kw in 'Fixes #7' 'Resolves #7' 'closes #7' 'fix #7' 'Closes acme/app#7' 'Closes https://github.com/acme/app/issues/7'; do
        sed -i.bak "s|Closes #42|$kw|" "$PR_BODY_FILE"
        run bash "$POLICY"
        [ "$status" -eq 0 ] || { echo "rejected: $kw"; return 1; }
        good_body > "$PR_BODY_FILE"
    done
}

@test "policy: HTML 주석·코드 펜스 안의 Closes 와 #0 은 이슈 연결로 인정하지 않는다" {
    for variant in '<!-- Closes #42 -->' $'```\nCloses #42\n```' 'Closes #0' 'see https://x.y/z?closes#1'; do
        good_body > "$PR_BODY_FILE"
        sed -i.bak '/Closes #42/d' "$PR_BODY_FILE"
        printf '%s\n' "$variant" >> "$PR_BODY_FILE"
        run bash "$POLICY"
        [ "$status" -eq 1 ] || { echo "wrongly accepted: $variant"; return 1; }
    done
}

@test "policy: no-issue 라벨이 있으면 이슈 연결 검사를 건너뛴다" {
    sed -i.bak '/Closes #42/d' "$PR_BODY_FILE"
    export PR_LABELS="no-issue,docs"
    run bash "$POLICY"
    [ "$status" -eq 0 ]
}

@test "policy: 변경 800줄 초과는 실패, 정확히 800줄은 통과" {
    files_json 'src/a.ts' 500 400 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 1 ]; [[ "$output" == *"800"* ]]
    files_json 'src/a.ts' 500 300 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 0 ]
}

@test "policy: 루트·워크스페이스 lockfile 은 제외하지만 깊은 경로의 lockfile 이름은 제외하지 않는다" {
    files_json 'pnpm-lock.yaml' 5000 4000 'packages/web/package-lock.json' 900 0 'src/a.ts' 10 0 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 0 ]
    files_json 'src/evil/nested/yarn.lock' 5000 0 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 1 ]
}

@test "policy: 스냅샷(.snap)은 본문 상한에서 빼되 2000줄 상한을 따로 둔다" {
    files_json '__snapshots__/a.snap' 1500 0 'src/a.ts' 10 0 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 0 ]
    files_json '__snapshots__/a.snap' 5000 0 > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 1 ]
}

@test "policy: 음수·문자열 additions 는 0 으로 취급한다" {
    printf '[{"path":"src/a.ts","additions":-5000,"deletions":0},{"path":"src/b.ts","additions":"900","deletions":"0"}]' > "$PR_FILES_JSON"
    run bash "$POLICY"; [ "$status" -eq 1 ]
}

@test "policy: large-pr-approved 라벨이 있으면 크기 검사를 건너뛴다" {
    files_json 'src/a.ts' 5000 0 > "$PR_FILES_JSON"
    export PR_LABELS="large-pr-approved"
    run bash "$POLICY"; [ "$status" -eq 0 ]
}

@test "policy: PR_MAX_LINES 로 상한을 바꿀 수 있다" {
    files_json 'src/a.ts' 100 0 > "$PR_FILES_JSON"
    export PR_MAX_LINES=50
    run bash "$POLICY"; [ "$status" -eq 1 ]
}

@test "policy: '테스트 방법' 섹션이 템플릿 그대로(비어 있음)이면 실패" {
    cat > "$PR_BODY_FILE" <<'BODY'
## 테스트

### 테스트 방법
<!-- 리뷰어가 검증할 수 있도록 테스트 절차와 결과를 기술 -->
```bash
# 테스트 실행 커맨드
```
<!-- 커버리지: __% -->

## 운영 안전성

### 롤백 계획
- 롤백 방법: revert
- 영향 범위:

Closes #1
BODY
    run bash "$POLICY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"테스트 방법"* ]]
}

@test "policy: '테스트 방법' 에 자리표시자(N/A · TBD · -)만 있거나 펜스 밖 텍스트만 있으면 실패" {
    for filler in 'N/A' 'TBD' '-' '- [ ] 나중에' '없음' $'```bash\nN/A\n```' '수동으로 확인함'; do
        good_body > "$PR_BODY_FILE"
        python3 - "$PR_BODY_FILE" "$filler" <<'PY'
import re, sys
p, filler = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
s = re.sub(r"### 테스트 방법\n.*?\n## 운영 안전성", "### 테스트 방법\n" + filler + "\n\n## 운영 안전성", s, flags=re.S)
open(p, "w", encoding="utf-8").write(s)
PY
        run bash "$POLICY"
        [ "$status" -eq 1 ] || { echo "wrongly accepted: $filler"; return 1; }
    done
}

@test "policy: 코드 펜스 안의 가짜 '### 테스트 방법' 제목은 섹션으로 보지 않는다" {
    good_body > "$PR_BODY_FILE"
    python3 - "$PR_BODY_FILE" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
# 진짜 섹션은 비우고, 코드 펜스 안에 가짜 제목 + 명령을 넣는다
s = s.replace("```bash\n# 테스트 실행 커맨드\npnpm test -- auth   # 42 passed\n```\n", "")
s = s.replace("## 관련 이슈", "## 기타\n```md\n### 테스트 방법\n```bash\nfake\n```\n```\n\n## 관련 이슈")
open(p, "w", encoding="utf-8").write(s)
PY
    run bash "$POLICY"
    [ "$status" -eq 1 ]
}

@test "policy: '롤백 계획'의 롤백 방법이 비어 있거나 자리표시자면 실패, 줄 자체가 없어도 이유를 출력한다" {
    for repl in '- 롤백 방법:' '- 롤백 방법: N/A' '- 롤백 방법: -'; do
        good_body > "$PR_BODY_FILE"
        sed -i.bak "s|- 롤백 방법: 이 PR 을 revert 한다|$repl|" "$PR_BODY_FILE"
        run bash "$POLICY"
        [ "$status" -eq 1 ] || { echo "wrongly accepted: $repl"; return 1; }
        [[ "$output" == *"롤백"* ]]
    done
    good_body > "$PR_BODY_FILE"
    sed -i.bak '/롤백 방법/d' "$PR_BODY_FILE"
    run bash "$POLICY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"::error::"*"롤백"* ]]
}

@test "policy: 볼드·전각 콜론 변형의 '롤백 방법' 도 인식한다" {
    sed -i.bak 's/- 롤백 방법: 이 PR 을 revert 한다/- **롤백 방법**： revert 한다/' "$PR_BODY_FILE"
    run bash "$POLICY"; [ "$status" -eq 0 ]
}

@test "policy: CRLF 본문과 제목 뒤 공백도 정상 처리" {
    sed -i.bak 's/$/\r/' "$PR_BODY_FILE"
    sed -i.bak 's/### 테스트 방법\r/### 테스트 방법  \r/' "$PR_BODY_FILE"
    run bash "$POLICY"; [ "$status" -eq 0 ]
}

@test "policy: 봇 PR(dependabot[bot] 또는 라벨 bot)은 필수 섹션 검사를 면제하되 이슈 연결은 라벨로 처리" {
    printf 'Bump actions/checkout from 4 to 5\n' > "$PR_BODY_FILE"
    export PR_AUTHOR="dependabot[bot]" PR_LABELS="no-issue"
    run bash "$POLICY"; [ "$status" -eq 0 ]
    export PR_AUTHOR="alice" PR_LABELS="no-issue,bot"
    run bash "$POLICY"; [ "$status" -eq 0 ]
    export PR_AUTHOR="alice" PR_LABELS="no-issue"
    run bash "$POLICY"; [ "$status" -eq 1 ]
}

@test "policy: 위반이 여러 개면 모두 출력한다" {
    sed -i.bak -e '/Closes #42/d' -e 's/- 롤백 방법: 이 PR 을 revert 한다/- 롤백 방법:/' "$PR_BODY_FILE"
    files_json 'src/a.ts' 900 0 > "$PR_FILES_JSON"
    run bash "$POLICY"
    [ "$status" -eq 1 ]
    [ "$(grep -c '::error::' <<< "$output")" -eq 3 ]
}
