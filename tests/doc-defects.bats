#!/usr/bin/env bats
# tests/doc-defects.bats — 규칙·가이드 문서에서 확인된 결함이 다시 들어오지 않게 막는다.
# 근거: 원래 dev-standards 저장소의 문서 결함 조사 · mutmut 3.8.1 실측(2026-11-04)

load helpers

MODEL_SCOPE="common/rules/ common/templates/ADVERSARIAL_REVIEW_CHECKLIST.md"

@test "rules: 모델 이름·버전과 절대 컨텍스트 크기를 박아 두지 않는다 (능력 등급·퍼센트로)" {
    cd "$REPO_ROOT"
    [ -f common/templates/ADVERSARIAL_REVIEW_CHECKLIST.md ]   # a renamed file must not silently drop out of scope
    # shellcheck disable=SC2086
    run git grep -nE '(Opus|Sonnet|Haiku) [0-9]|GPT-[0-9]|Gemini [0-9]|[0-9]+K / [0-9]+K' -- $MODEL_SCOPE
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    # shellcheck disable=SC2086
    run git grep -nwE 'Opus|Sonnet|Haiku' -- $MODEL_SCOPE
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "opentelemetry: 폐기된 semconv 속성(db.system · rpc.service) 대신 현행 이름을 쓴다" {
    local f="$REPO_ROOT/common/rules/opentelemetry.md"
    grep -q '`db\.system\.name`' "$f"
    grep -q '`rpc\.method`' "$f"
    run grep -nE '`db\.system`' "$f"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    # `rpc.service` may appear only inside a deprecation note
    run bash -c "grep -oE '\`rpc\.service\`[^,)]*' '$f' | grep -v 'is deprecated'"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "mutation guide: mutmut 2 전용 옵션·명령이 없다" {
    run grep -nE -- '--paths-to-mutate|--no-progress|mutmut html|^paths_to_mutate|^tests_dir|^runner =|cargo mutants --diff|\|\| true' \
        "$REPO_ROOT/docs/guides/mutation-testing-guide.md"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

# The CI example's jq gate, extracted from the guide and run on mutmut export-cicd-stats shaped inputs.
gate_on() {
    local expr
    expr="$(sed -nE "s/^ *jq -e '(.*)' \\\\$/\1/p" "$REPO_ROOT/docs/guides/mutation-testing-guide.md")"
    [ -n "$expr" ] || { echo "gate expression not found"; return 2; }
    jq -e "$expr" <<< "$1" >/dev/null
}

@test "mutation guide: CI 예시의 점수 판정이 약한 테스트·테스트가 닿지 않은 변이·변이 0개에서 실패하고, 강한 테스트는 통과한다" {
    local zero='"timeout":0,"suspicious":0,"skipped":0,"segfault":0,"check_was_interrupted_by_user":0'
    # mutmut 3 `run` exits 0 in all of these (measured) — the gate is the only thing that fails CI
    run gate_on "{\"killed\":0,\"survived\":4,\"total\":4,\"no_tests\":0,$zero}"     # weak tests
    [ "$status" -eq 1 ] || { echo "weak: $status $output"; return 1; }
    run gate_on "{\"killed\":4,\"survived\":0,\"total\":24,\"no_tests\":20,$zero}"   # most code untested (review repro)
    [ "$status" -eq 1 ] || { echo "no_tests: $status $output"; return 1; }
    run gate_on "{\"killed\":0,\"survived\":0,\"total\":0,\"no_tests\":0,$zero}"     # nothing mutated
    [ "$status" -eq 1 ] || { echo "empty: $status $output"; return 1; }
    run gate_on "{\"killed\":4,\"survived\":0,\"total\":4,\"no_tests\":0,$zero}"     # strong tests
    [ "$status" -eq 0 ] || { echo "strong: $status $output"; return 1; }
}

@test "ai review guide: AI 공동 저자 표시를 의무·판정 근거로 쓰지 않는다 (자기신고는 강제 근거가 못 된다)" {
    local f="$REPO_ROOT/docs/guides/ai-code-review-guide.md"
    run grep -nE '(반드시|의무|필수)[^|]*(Co-Authored-By|공동 저자)' "$f"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
    # no gate that switches on only when an AI trailer is present (dropping the trailer would skip it)
    run grep -nE 'ai_commits|codeDetection\.markers' "$f"
    [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "guides: 이번에 고친 문서의 코드 펜스가 짝이 맞는다 (어긋나면 설명이 코드 블록으로 렌더링된다)" {
    local f n
    for f in docs/guides/ai-code-review-guide.md docs/guides/mutation-testing-guide.md; do
        n="$(grep -c '^ *```' "$REPO_ROOT/$f")"
        [ $(( n % 2 )) -eq 0 ] || { echo "$f: $n fence lines"; return 1; }
    done
}

@test "context-engineering: context rot · just-in-time · compaction · 서브에이전트 요약 반환을 다룬다" {
    local f="$REPO_ROOT/common/rules/context-engineering.md" term missing=""
    for term in "context rot" "just-in-time" "compaction" "condensed summar"; do
        grep -qi -- "$term" "$f" || missing="$missing [$term]"
    done
    [ -z "$missing" ] || { echo "missing:$missing"; return 1; }
}
