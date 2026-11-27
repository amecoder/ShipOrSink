#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031  # @test 는 각각 서브셸 — export 가 테스트 밖으로 새지 않는 것이 의도
# scripts/install-dev-tools.sh — 현황 출력·도움말 계약 (실제 설치는 하지 않는다)

load 'helpers'

INSTALLER="$PROJECT_ROOT/scripts/install-dev-tools.sh"

@test "install: --check 는 8종 도구를 모두 나열한다" {
    run bash "$INSTALLER" --check
    for t in gh jq shellcheck bats actionlint markdownlint-cli2 gitleaks pre-commit; do
        [[ "$output" == *"$t"* ]] || { echo "not listed: $t"; return 1; }
    done
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "install: --help 는 exit 0 이고 사용법을 보여준다" {
    run bash "$INSTALLER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"사용법"* ]]
}

@test "install: --pm 은 brew|apt|dnf|pacman|scoop|none 만 받는다" {
    run bash "$INSTALLER" --pm bogus --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"--pm"* ]]
    run bash "$INSTALLER" --pm none --check
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" == *"패키지 관리자: none"* ]]
}

@test "install: 알 수 없는 옵션은 exit 1" {
    run bash "$INSTALLER" --bogus
    [ "$status" -eq 1 ]
}
