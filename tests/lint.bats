#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# 정적 검사 — shellcheck · actionlint · JSON/YAML 파싱. 도구가 없으면 skip.

load 'helpers'

@test "lint: 모든 셸 스크립트가 shellcheck 를 통과" {
    command -v shellcheck >/dev/null || skip "shellcheck 없음 — scripts/install-dev-tools.sh"
    cd "$PROJECT_ROOT"
    mapfile -t files < <(git ls-files '*.sh' '*.bats' 'tests/*.bash')
    run shellcheck -x "${files[@]}"
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "lint: 워크플로우 템플릿과 이 저장소의 워크플로우가 actionlint 를 통과" {
    command -v actionlint >/dev/null || skip "actionlint 없음 — scripts/install-dev-tools.sh"
    cd "$REPO_ROOT"
    # dependabot.yml 은 워크플로우가 아니므로 제외
    run actionlint -shellcheck= common/ci-templates/*.yml common/security-templates/*-ci.yml \
        common/security-templates/security-review.yml common/github-templates/workflows/*.yml "$PROJECT_ROOT"/.github/workflows/*.yml
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "lint: 모든 JSON 템플릿이 파싱된다" {
    cd "$PROJECT_ROOT"
    # devcontainer.json 은 JSONC(주석 허용) 규격이라 jq 로 검증하지 않는다
    for f in $(git ls-files '*.json' | grep -v 'devcontainer.json'); do
        jq -e . "$f" >/dev/null || { echo "invalid JSON: $f"; return 1; }
    done
}
