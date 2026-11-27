#!/usr/bin/env bats
# tests/enforcement-pbt.bats — 속성 기반 테스트 예제가 실제로 돌고, 버그를 넣으면 반례를 찾아 실패하는지 (로드맵 A15).
#   Python: common/testing-templates/property-example.py   — Hypothesis (버전: .github/workflows/ci.yml HYPOTHESIS_VERSION)
#   TS:     common/testing-templates/property-example.test.ts — fast-check + Vitest (버전: tests/enforcement-ts lockfile)
# 반증: 예시(100÷3, 나머지 1)는 못 잡는 버그 — 나머지 센트를 최대 5개만 나눠 준다 — 를 넣으면 예시는 통과하고
#       속성 테스트만 반례와 함께 실패해야 한다(속성 테스트가 예시보다 더 잡는다는 주장의 증거).
# 린트: 예제는 하위 프로젝트에 그대로 복사되므로 python 템플릿 ruff 설정 · TS 템플릿 Prettier 설정을 통과해야 한다.
# Python 은 uvx 가 핀 버전을 받는다(첫 실행은 PyPI) · TS 는 TS_TOOLS_DIR(npm ci tests/enforcement-ts) 이 있어야 한다.

load helpers

TT="$REPO_ROOT/common/testing-templates"
CI="$PROJECT_ROOT/.github/workflows/ci.yml"

ci_env() { V="$1" yq -r '.env[strenv(V)]' "$CI"; }

py_project() { # [sed-expr]
    local d
    d="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp "$TT/property-example.py" "$d/test_property_example.py"
    [ -z "${1:-}" ] || sed_i "$1" "$d/test_property_example.py"
    echo "$d"
}

py_rc() { # dir
    local hv pv
    hv="$(ci_env HYPOTHESIS_VERSION)"
    pv="$(ci_env PYTEST_VERSION)"
    [ "$hv" != null ] && [ "$pv" != null ] || { echo "HYPOTHESIS_VERSION / PYTEST_VERSION missing in ci.yml"; return 2; }
    (cd "$1" && uvx -q --from "pytest==$pv" --with "hypothesis==$hv" pytest -q -p no:cacheprovider test_property_example.py 2>&1)
}

ts_project() { # [sed-expr]
    local d
    d="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    ln -s "$TS_TOOLS_DIR/node_modules" "$d/node_modules"
    mkdir -p "$d/tests"
    cp "$TT/property-example.test.ts" "$d/tests/"
    [ -z "${1:-}" ] || sed_i "$1" "$d/tests/property-example.test.ts"
    echo "$d"
}

ts_rc() { (cd "$1" && "$TS_TOOLS_DIR/node_modules/.bin/vitest" run --root . 2>&1); }

require_ts() {
    if [ -n "${TS_TOOLS_DIR:-}" ] && [ -f "$TS_TOOLS_DIR/node_modules/fast-check/package.json" ]; then return 0; fi
    [ "${TEMPLATE_TOOLS_REQUIRED:-0}" != 1 ] || { echo "TS_TOOLS_DIR with fast-check missing" >&2; return 1; }
    skip "TS_TOOLS_DIR not set up (npm ci tests/enforcement-ts into it)"
}

PY_BUG='s/    base, remainder = divmod(total_cents, parts)/    base, remainder = total_cents \/\/ parts, min(total_cents % parts, 5)/'
TS_BUG='s/  const remainder = totalCents - base \* parts;/  const remainder = Math.min(totalCents - base * parts, 5);/'

@test "pbt: Python 예제(Hypothesis)가 통과한다" {
    require_tool uvx
    require_tool yq
    run py_rc "$(py_project)"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    grep -Eq '3 passed' <<< "$output" || { echo "$output"; return 1; }   # pytest summary: 2 properties + 1 example
}

@test "pbt 반증: Python — 예시가 놓치는 버그(나머지 최대 5센트)를 Hypothesis 속성 테스트만 반례로 잡는다" {
    require_tool uvx
    require_tool yq
    dir="$(py_project "$PY_BUG")"
    grep -Fq 'min(total_cents % parts, 5)' "$dir/test_property_example.py" || { echo "bug not injected"; return 1; }
    run py_rc "$dir"
    [ "$status" -ne 0 ] || { echo "bug accepted: $output"; return 1; }
    grep -Fq 'Failing test case: test_shares_add_up_to_total(' <<< "$output" || { echo "no counterexample: $output"; return 1; }
    grep -Eq '1 failed, 2 passed' <<< "$output" || { echo "example test should still pass: $output"; return 1; }
}

@test "pbt: Python 예제가 python 템플릿 ruff 설정을 통과한다" {
    require_tool uvx
    local d ruff_ver
    d="$(py_project)"
    sed -n '/^\[tool\.ruff\]/,/^\[tool\.mypy\]/p' "$REPO_ROOT/python/templates/pyproject-quality.toml" | sed '$d' > "$d/pyproject.toml"
    ruff_ver="$(sed -nE 's/^[[:space:]]*rev: v?([0-9.]+)[[:space:]]*$/\1/p' <(grep -A1 'astral-sh/ruff-pre-commit' "$REPO_ROOT/python/templates/.pre-commit-config.yaml") | head -1)"
    [ -n "$ruff_ver" ] || { echo "ruff rev not found in python/templates/.pre-commit-config.yaml"; return 1; }
    run bash -c "cd '$d' && uvx -q --from 'ruff==$ruff_ver' ruff check --no-cache test_property_example.py"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "pbt: TS 예제(fast-check)가 통과한다" {
    require_ts
    run ts_rc "$(ts_project)"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    grep -Eq 'Tests +3 passed' <<< "$output" || { echo "$output"; return 1; }
}

@test "pbt 반증: TS — 예시가 놓치는 버그(나머지 최대 5센트)를 fast-check 속성 테스트만 반례로 잡는다" {
    require_ts
    dir="$(ts_project "$TS_BUG")"
    grep -Fq 'Math.min(totalCents - base * parts, 5)' "$dir/tests/property-example.test.ts" || { echo "bug not injected"; return 1; }
    run ts_rc "$dir"
    [ "$status" -ne 0 ] || { echo "bug accepted: $output"; return 1; }
    grep -Fq 'Counterexample:' <<< "$output" || { echo "no counterexample: $output"; return 1; }
    grep -Fq 'shares add up to the total' <<< "$output" || { echo "$output"; return 1; }
    grep -Eq 'Tests +1 failed \| 2 passed' <<< "$output" || { echo "example test should still pass: $output"; return 1; }
}

@test "pbt: TS 예제가 TS 템플릿 Prettier 설정을 통과한다 (tailwind 플러그인 항목만 제외)" {
    require_ts
    local d
    d="$(ts_project)"
    jq 'del(.plugins, .tailwindStylesheet)' "$REPO_ROOT/typescript-react/templates/.prettierrc" > "$d/.prettierrc"
    run bash -c "cd '$d' && '$TS_TOOLS_DIR/node_modules/.bin/prettier' --check tests/property-example.test.ts"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "pbt: fast-check 핀이 하위 프로젝트 설치 목록과 테스트 lockfile 에서 같다" {
    local listed locked
    listed="$(sed -nE 's/^fast-check@([0-9.]+)$/\1/p' "$REPO_ROOT/typescript-react/templates/dev-dependencies.txt")"
    locked="$(jq -r '.packages["node_modules/fast-check"].version' "$PROJECT_ROOT/tests/enforcement-ts/package-lock.json")"
    [ -n "$listed" ] && [ "$listed" = "$locked" ] || { echo "dev-dependencies=$listed lockfile=$locked"; return 1; }
}
