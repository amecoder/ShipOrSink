#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# apply.sh — github 컴포넌트·훅 4종·신규 규칙 배치 계약

load 'helpers'
bats_require_minimum_version 1.5.0  # `run !`

setup() {
    T="$(mktemp -d)"
}

teardown() { rm -rf "$T"; }

@test "apply: --only github 가 이슈 폼·라벨·ruleset·스크립트·워크플로우를 .github/ 에 배치" {
    run bash "$REPO_ROOT/apply.sh" --only github --target "$T"
    [ "$status" -eq 0 ]
    for f in ISSUE_TEMPLATE/ai-task.yml ISSUE_TEMPLATE/bug-report.yml ISSUE_TEMPLATE/feature-request.yml \
             ISSUE_TEMPLATE/config.yml labels.json rulesets/main-protection.json \
             scripts/apply-github-settings.sh scripts/pr-policy.sh scripts/ai-ready-guard.sh \
             workflows/pr-checks.yml workflows/security-review.yml workflows/ai-ready-guard.yml; do
        [ -f "$T/.github/$f" ] || { echo "missing: .github/$f"; return 1; }
    done
    [ -x "$T/.github/scripts/apply-github-settings.sh" ]
    [ -x "$T/.github/scripts/pr-policy.sh" ]
}

@test "apply: --only github --pick ruleset-solo 는 solo 프로필을 main-protection.json 이름으로 배치" {
    run bash "$REPO_ROOT/apply.sh" --only github --pick "ruleset-solo" --target "$T"
    [ "$status" -eq 0 ]
    [ "$(jq -r .name "$T/.github/rulesets/main-protection.json")" = "main-protection-solo" ]
}

@test "apply: --only github --pick ruleset 은 ruleset 만 배치" {
    run bash "$REPO_ROOT/apply.sh" --only github --pick "ruleset" --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.github/rulesets/main-protection.json" ]
    [ ! -f "$T/.github/labels.json" ]
    [ ! -d "$T/.github/ISSUE_TEMPLATE" ]
}

@test "apply: --only hooks 가 5개 파일을 복사한다 (auto-format · guard · test-receipt · receipt-lib · hooklib.py)" {
    run bash "$REPO_ROOT/apply.sh" --only hooks --target "$T"
    [ "$status" -eq 0 ]
    for f in auto-format.sh pre-tool-use-guard.sh test-receipt.sh receipt-lib.sh hooklib.py; do
        [ -f "$T/.claude/hooks/$f" ] || { echo "missing: $f"; return 1; }
    done
    [ -x "$T/.githooks/pre-push" ]
    [[ "$output" == *"5개"* ]]
    [[ "$output" == *"core.hooksPath"* ]]
}

@test "apply: --dry-run 은 디렉터리조차 만들지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --only github --dry-run --target "$T"
    [ "$status" -eq 0 ]
    [ ! -d "$T/.github" ]
    run bash "$REPO_ROOT/apply.sh" --only hooks --dry-run --target "$T"
    [ ! -d "$T/.claude" ]
}

@test "apply: --only settings 의 settings.json 이 영수증 훅과 TEST_RECEIPT_REQUIRED 를 담는다" {
    run bash "$REPO_ROOT/apply.sh" --only settings --target "$T"
    [ "$status" -eq 0 ]
    jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[] | select(.command | contains("test-receipt.sh"))' "$T/.claude/settings.json"
    [ "$(jq -r '.env.TEST_RECEIPT_REQUIRED' "$T/.claude/settings.json")" = "1" ]
}

@test "apply: --only skills 가 워크플로우 스킬 5개를 .claude/skills/<name>/SKILL.md 로 배치" {
    run bash "$REPO_ROOT/apply.sh" --only skills --target "$T"
    [ "$status" -eq 0 ]
    for s in refactoring vibe-to-production ai-review-loop ai-task-spec plan-mode-workflow; do
        [ -f "$T/.claude/skills/$s/SKILL.md" ] || { echo "missing: $s"; return 1; }
    done
    [[ "$output" == *"5개"* ]]
}

@test "apply: --level slim --dry-run 에 skills 가 포함되고 옛 규칙 이름은 rules 로 배치되지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --level slim --dry-run --target "$T"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL.md"* ]]
    run bash "$REPO_ROOT/apply.sh" --only rules --target "$T"
    [ ! -f "$T/.claude/rules/refactoring.md" ]
    [ ! -f "$T/.claude/rules/plan-mode-workflow.md" ]
}

@test "apply: 대상에 .gitignore 가 이미 있어도 레벨 적용이 set -e 로 죽지 않고 패턴을 추가한다 (#13 회귀)" {
    printf 'node_modules/\n' > "$T/.gitignore"   # 일부 패턴만 있는 기존 .gitignore
    run bash -c "printf 'y\n' | bash '$REPO_ROOT/apply.sh' --level slim --target '$T'"
    [ "$status" -eq 0 ] || { echo "$output" | tail -5; return 1; }
    grep -q '^__pycache__/' "$T/.gitignore"      # gitignore-additions 의 첫 패턴이 실제로 추가됨
    [[ "$output" == *"패턴 추가"* ]]
    [ -f "$T/.claude/rules/tdd.md" ]             # 이후 단계까지 진행됨
}

@test "apply: --only rules --pick oop,functional 이 두 규칙을 배치" {
    run bash "$REPO_ROOT/apply.sh" --only rules --pick "oop,functional" --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.claude/rules/oop.md" ]
    [ -f "$T/.claude/rules/functional.md" ]
}

@test "apply: slim 레벨 규칙에 oop.md · functional.md 가 포함된다" {
    run bash "$REPO_ROOT/apply.sh" --only rules --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.claude/rules/oop.md" ]
    [ -f "$T/.claude/rules/functional.md" ]
}

@test "apply: --level standard --dry-run 출력에 github 컴포넌트가 나타난다" {
    run bash "$REPO_ROOT/apply.sh" --level standard --dry-run --target "$T"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pr-checks.yml"* ]]
    [[ "$output" == *"security-review.yml"* ]]
    [[ "$output" == *"ai-task.yml"* ]]
    [[ "$output" == *"test-receipt.sh"* ]]
}

@test "apply: --level slim --dry-run 은 github 컴포넌트를 포함하지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --level slim --dry-run --target "$T"
    [ "$status" -eq 0 ]
    [[ "$output" != *"pr-checks.yml"* ]]
}

@test "apply: --help 에 github 컴포넌트와 신규 규칙이 안내된다" {
    run bash "$REPO_ROOT/apply.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"--only github"* ]]
    [[ "$output" == *"oop"* ]]
    [[ "$output" == *"functional"* ]]
}

@test "apply: 알 수 없는 github pick 은 경고만 내고 exit 0" {
    run bash "$REPO_ROOT/apply.sh" --only github --pick "nope" --target "$T"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN"* ]]
}

# ─── 2026-10-11 적대적 리뷰 반영 ──────────────────────────────────────────

@test "apply: 기존 .gitignore 에 .env.local 만 있어도 .env 를 줄 단위로 추가한다 (부분 문자열 비교 금지)" {
    printf '.env.local\nnode_modules/\n' > "$T/.gitignore"
    run bash "$REPO_ROOT/apply.sh" --level slim --yes --target "$T"
    [ "$status" -eq 0 ] || { echo "$output" | tail -5; return 1; }
    grep -qx '.env' "$T/.gitignore"
}

@test "apply: .gitignore 가 없으면 공용 패턴(gitignore-additions)으로 만들고 node_modules·coverage 를 포함한다" {
    run bash "$REPO_ROOT/apply.sh" --level slim --yes --target "$T"
    [ "$status" -eq 0 ]
    grep -qx '.env' "$T/.gitignore"
    grep -qx 'node_modules/' "$T/.gitignore"
    grep -qx 'coverage/' "$T/.gitignore"
}

@test "apply: --yes 면 GitHub ruleset 은 solo 프로필 (1인 저장소 머지 차단 방지)" {
    run bash "$REPO_ROOT/apply.sh" --only github --yes --target "$T"
    [ "$status" -eq 0 ]
    [ "$(jq -r .name "$T/.github/rulesets/main-protection.json")" = "main-protection-solo" ]
}

@test "apply: 대화형에서 '팀' 을 고르면 팀용 ruleset" {
    run bash -c "printf 'n\n' | bash '$REPO_ROOT/apply.sh' --only github --target '$T'"
    [ "$status" -eq 0 ]
    [ "$(jq -r .name "$T/.github/rulesets/main-protection.json")" = "main-protection" ]
}

@test "apply: --yes 면 AGENTS.md 에 ai-ready 이슈 게이트 절이 빠진다, 대화형 y 면 남는다" {
    run bash "$REPO_ROOT/apply.sh" --only templates --pick agents --yes --target "$T"
    [ "$status" -eq 0 ]
    run ! grep -q 'ai-ready' "$T/AGENTS.md"
    rm -f "$T/AGENTS.md" "$T/.dev-standards.manifest"
    run bash -c "printf 'y\n' | bash '$REPO_ROOT/apply.sh' --only templates --pick agents --target '$T'"
    [ "$status" -eq 0 ]
    grep -q 'ai-ready' "$T/AGENTS.md"
}

@test "apply: 기존 settings 는 덮어쓰지 않고 병합한다 (사용자 allow·model 보존, 훅 중복 없음)" {
    local s="$T/.claude/settings.json"
    mkdir -p "$T/.claude"
    printf '{"model":"opus","permissions":{"allow":["Bash(make *)"]}}\n' > "$s"
    run bash "$REPO_ROOT/apply.sh" --only settings --yes --target "$T"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$(jq -r .model "$s")" = "opus" ]
    jq -e '.permissions.allow | index("Bash(make *)")' "$s"
    jq -e '.hooks.PostToolUse[] | select(.matcher=="Bash")' "$s"
    run bash "$REPO_ROOT/apply.sh" --only settings --yes --target "$T"
    [ "$(jq '[.hooks.PreToolUse[].hooks[].command] | length' "$s")" -eq 1 ]
}

@test "apply: 적용 기록(.dev-standards.manifest)을 남기고 --check 는 최신이면 0" {
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.dev-standards.manifest" ]
    grep -q "^.claude/rules/tdd.md	common/rules/tdd.md	" "$T/.dev-standards.manifest"
    run bash "$REPO_ROOT/apply.sh" --check --target "$T"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OK"* ]]
}

@test "apply: 원본이 바뀌고 로컬 수정이 없으면 --check 는 OUTDATED, --yes 재적용은 자동 갱신" {
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    printf 'old rule\n' > "$T/.claude/rules/tdd.md"
    old_hash="$(shasum -a 256 "$T/.claude/rules/tdd.md" | cut -d' ' -f1)"
    awk -v h="$old_hash" 'BEGIN{FS=OFS="\t"} $1==".claude/rules/tdd.md"{$3=h} {print}' \
        "$T/.dev-standards.manifest" > "$T/m.tmp" && mv "$T/m.tmp" "$T/.dev-standards.manifest"
    run bash "$REPO_ROOT/apply.sh" --check --target "$T"
    [ "$status" -eq 1 ]
    [[ "$output" == *"OUTDATED"*"tdd.md"* ]]
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    cmp -s "$T/.claude/rules/tdd.md" "$REPO_ROOT/common/rules/tdd.md"
}

@test "apply: 사용자가 고친 파일은 --check 에서 MODIFIED, --yes 재적용이 덮어쓰지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    printf '\n# my local note\n' >> "$T/.claude/rules/tdd.md"
    run bash "$REPO_ROOT/apply.sh" --check --target "$T"
    [[ "$output" == *"MODIFIED"*"tdd.md"* ]]
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    grep -q 'my local note' "$T/.claude/rules/tdd.md"
}

@test "apply: --diff 는 바뀐 파일의 diff 를 보여 주고 아무것도 쓰지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    printf 'old rule\n' > "$T/.claude/rules/tdd.md"
    run bash "$REPO_ROOT/apply.sh" --diff --target "$T"
    [[ "$output" == *"old rule"* ]]
    grep -qx 'old rule' "$T/.claude/rules/tdd.md"
}

@test "apply: Groovy build.gradle 만 있으면 java-spring 으로 감지 (kotlin 아님)" {
    printf 'plugins { id "java" }\n' > "$T/build.gradle"
    run bash "$REPO_ROOT/apply.sh" --only rules --yes --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.claude/rules/java.md" ]
    [ ! -f "$T/.claude/rules/kotlin.md" ]
}

@test "apply: --pick flutter 처럼 언어 이름으로 고르면 언어 규칙 파일로 매핑" {
    run bash "$REPO_ROOT/apply.sh" --only rules --pick flutter --target "$T"
    [ "$status" -eq 0 ]
    [ -f "$T/.claude/rules/dart.md" ]
}

@test "apply: 셸의 LANG(로케일) 을 덮어쓰지 않는다" {
    run ! grep -nE '^LANG=' "$REPO_ROOT/apply.sh"
}

@test "apply: 비대화형(stdin 없음) + --yes 는 레벨 적용이 프롬프트 없이 끝난다" {
    run bash "$REPO_ROOT/apply.sh" --level standard --yes --target "$T" < /dev/null
    [ "$status" -eq 0 ] || { echo "$output" | tail -5; return 1; }
    [ -f "$T/CLAUDE.md" ]
}

@test "apply: --help 는 색 코드를 글자(\\033[…)로 찍지 않는다" {
    run bash "$REPO_ROOT/apply.sh" --help
    [ "$status" -eq 0 ]
    ! grep -qF '\033[' <<< "$output" || { echo "literal escape codes: $(grep -cF '\033[' <<< "$output") lines"; return 1; }
    grep -q '레벨별 상세 설명' <<< "$output"
    grep -qF 'bash "$SOS_STANDARDS/apply.sh" --level slim' <<< "$output"
}
