#!/usr/bin/env bats
# shellcheck shell=bash disable=SC2030,SC2031
# ai-ready-guard.sh — "ai-ready 는 사람만 붙인다" 판정 계약

load 'helpers'

GUARD="$REPO_ROOT/common/github-templates/scripts/ai-ready-guard.sh"

@test "ai-ready-guard: ai-ready 가 아닌 라벨은 누가 붙여도 allow" {
    LABEL=bug SENDER='claude[bot]' SENDER_TYPE=Bot PERMISSION=none run bash "$GUARD"
    [ "$status" -eq 0 ]; [ "$output" = "allow" ]
}

@test "ai-ready-guard: 봇 계정([bot] 로그인 또는 type=Bot)이 ai-ready 를 붙이면 deny" {
    LABEL=ai-ready SENDER='claude[bot]' SENDER_TYPE=Bot PERMISSION=write run bash "$GUARD"
    [ "$status" -eq 1 ]; [[ "$output" == deny:* ]]
    LABEL=ai-ready SENDER='github-actions[bot]' SENDER_TYPE=User PERMISSION=admin run bash "$GUARD"
    [ "$status" -eq 1 ]
    LABEL=ai-ready SENDER='someapp' SENDER_TYPE=Bot PERMISSION=admin run bash "$GUARD"
    [ "$status" -eq 1 ]
}

@test "ai-ready-guard: write/maintain/admin 권한의 사람은 allow, triage/read/none 은 deny" {
    for p in write maintain admin; do
        LABEL=ai-ready SENDER=alice SENDER_TYPE=User PERMISSION=$p run bash "$GUARD"
        [ "$status" -eq 0 ] || { echo "denied: $p"; return 1; }
    done
    for p in triage read none ''; do
        LABEL=ai-ready SENDER=alice SENDER_TYPE=User PERMISSION=$p run bash "$GUARD"
        [ "$status" -eq 1 ] || { echo "allowed: $p"; return 1; }
        [[ "$output" == *"$p"* || -z "$p" ]]
    done
}

@test "ai-ready-guard: GUARDED_LABEL 로 보호 라벨 이름을 바꿀 수 있다" {
    GUARDED_LABEL=go LABEL=go SENDER='x[bot]' SENDER_TYPE=Bot run bash "$GUARD"
    [ "$status" -eq 1 ]
    GUARDED_LABEL=go LABEL=ai-ready SENDER='x[bot]' SENDER_TYPE=Bot run bash "$GUARD"
    [ "$status" -eq 0 ]
}
