#!/usr/bin/env bats
# tests/enforcement-coverage-langs.bats — 공용 커버리지 게이트(common/testing-templates/coverage-gate.sh)를
# 전체 80% 검사 위에 더 건 6개 언어의 연결을 실행 결과로 판정 (로드맵 3단계 T1 · 사용자 결정 2026-11-10: 함께 둔다).
#   CI   — python · go · typescript-react: common/ci-templates/ci-<lang>.yml 의 test 잡, PR 에서만 도는 단계
#          "Coverage gate (changed lines + ratchet)". 단계의 run: 을 그대로 꺼내 fixture 저장소에서 실행한다.
#          Python·Go 는 실제 도구로 리포트를 만든다(pytest-cov · go test + gocover-cobertura). TS 는 vitest 를
#          설치하지 않으므로 vitest 5.1.0 coverage-v8 이 쓰는 모양(SF:src/… 상대 경로, 2026-11-10 실측)으로 lcov 를 쓴다.
#   훅   — csharp-dotnet · flutter-dart · ruby-rails: 리포트를 만드는 기존 pre-push 훅 뒤의 훅 coverage-gate.
#          Dart 는 flutter 없이 Flutter 모양(SF:lib/…)의 lcov 로 훅을 실행한다. C#·Ruby 는 실제 dotnet test ·
#          rspec 가 쓴 리포트로 enforcement-csharp.bats · enforcement-ruby.bats 가 게이트 훅을 실행한다.
# 판정: 바뀐 줄 = 한도(정본)% 는 통과, 한도-1 % 는 실패. 전체 80% 검사는 각 언어 enforcement 테스트가 따로 본다.

load helpers

THRESHOLDS="$REPO_ROOT/common/quality-thresholds.yaml"
GATE="$REPO_ROOT/common/testing-templates/coverage-gate.sh"
STEP="Coverage gate (changed lines + ratchet)"

setup() {
    require_tool yq
}

limit() { yq -r '.thresholds.coverage' "$THRESHOLDS"; }

require_gate_tools() {
    require_tool git
    require_tool python3
    command -v uvx >/dev/null 2>&1 || require_tool pipx
}

# Template locations — the falsification test points these at edited copies.
ci_file() { echo "${CI_DIR:-$REPO_ROOT/common/ci-templates}/ci-$1.yml"; }
hook_config() { echo "${TPL_ROOT:-$REPO_ROOT}/$1/templates/.pre-commit-config.yaml"; }

# A repo with scripts/coverage-gate.sh on main (bootstrap copies it there) and origin/main at main; the working
# tree is on `feature`. Extra arguments are .gitignore lines (report files). Prints its path.
gate_repo() {
    local dir
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    git -C "$dir" init -q -b main
    mkdir -p "$dir/scripts"
    cp "$GATE" "$dir/scripts/coverage-gate.sh"
    printf '%s\n' "$@" > "$dir/.gitignore"
    git -C "$dir" add -A && git -C "$dir" -c user.email=t@t -c user.name=t commit -qm base
    git -C "$dir" update-ref refs/remotes/origin/main main
    git -C "$dir" switch -qc feature
    echo "$dir"
}

commit_all() { git -C "$1" add -A && git -C "$1" -c user.email=t@t -c user.name=t commit -qm change; }

# The run: script of a named step of the test job.
step_run() { # workflow step-name
    S="$2" yq -r '.jobs.test.steps[] | select(.name == strenv(S)) | .run' "$1"
}

# Runs the CI gate step as a pull request into main would.
run_ci_gate() { # dir lang
    local s
    s="$(step_run "$(ci_file "$2")" "$STEP")"
    [ -n "$s" ] && [ "$s" != "null" ] || { echo "$2: no step \"$STEP\""; return 2; }
    (cd "$1" && BASE_REF=main bash -e -c "$s" 2>&1)
}

# edge (K = limit) must pass, over (K = limit - 1) must fail with the gate's marker.
edge_over() { # runner(dir) writer(dir K) — writer builds the change and the report, runner judges it
    local e o out rc
    e="$("$2" "$(limit)")" || { echo "edge setup failed: $e"; return 1; }
    o="$("$2" $(( $(limit) - 1 )))" || { echo "over setup failed: $o"; return 1; }
    out="$("$1" "$e")" || { echo "edge rejected: $out"; return 1; }
    rc=0; out="$("$1" "$o")" || rc=$?
    [ "$rc" -ne 0 ] || { echo "over accepted (exit 0): $out"; return 1; }
    grep -qF "FAIL: changed-line coverage is below $(limit)%" <<< "$out" || { echo "over: unexpected output: $out"; return 1; }
}

# ── python: 100 two-statement functions, a test calls k: changed statements covered = (100 + k) / 200 ─────
py_change() { # K-percent → dir
    local d i k=$(( 2 * $1 - 100 ))
    d="$(gate_repo coverage.xml .coverage __pycache__/)"
    mkdir -p "$d/src/fx" "$d/tests"; touch "$d/src/fx/__init__.py"
    for i in $(seq 1 100); do printf 'def f%d():\n    return %d\n\n\n' "$i" "$i"; done > "$d/src/fx/m.py"
    { echo "from fx.m import *  # noqa: F403"; echo; echo "def test_calls():"
      for i in $(seq 1 "$k"); do echo "    f$i()  # noqa: F405"; done; } > "$d/tests/test_m.py"
    commit_all "$d"
    (cd "$d" && PYTHONPATH=src pytest tests --cov=src --cov-report=xml:coverage.xml -q -p no:cacheprovider >/dev/null 2>&1)
    [ -f "$d/coverage.xml" ] || { echo "pytest-cov wrote no coverage.xml"; return 1; }
    echo "$d"
}
py_gate() { run_ci_gate "$1" python; }

@test "coverage-langs: python — CI 게이트 단계가 pytest-cov 리포트로 바뀐 줄 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    require_tool pytest
    pytest --help 2>/dev/null | grep -q -- '--cov-report' || require_tool pytest-cov   # plugin, not a command
    run edge_over py_gate py_change
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# ── go: 100 one-statement functions, a test calls k of them: changed lines covered = k % ─────────────────
go_change() { # K → dir
    local d i
    d="$(gate_repo coverage.out coverage.xml)"
    mkdir -p "$d/fx"
    printf 'module example.com/fx\n\ngo 1.22\n' > "$d/go.mod"
    { printf 'package fx\n'; for i in $(seq 1 100); do printf '\nfunc F%d() int {\n\treturn %d\n}\n' "$i" "$i"; done; } > "$d/fx/m.go"
    { printf 'package fx\n\nimport "testing"\n\nfunc TestCalls(t *testing.T) {\n'
      for i in $(seq 1 "$1"); do printf '\t_ = F%d()\n' "$i"; done
      printf '}\n'; } > "$d/fx/m_test.go"
    commit_all "$d"
    (cd "$d" && go test -coverprofile=coverage.out ./... >/dev/null 2>&1) || { echo "go test failed"; return 1; }
    local conv
    conv="$(step_run "$(ci_file go)" "Convert coverage to Cobertura")"
    [ -n "$conv" ] && [ "$conv" != "null" ] || { echo "ci-go.yml: no step \"Convert coverage to Cobertura\""; return 1; }
    (cd "$d" && GOCOVER_COBERTURA_VERSION="$(yq -r '.env.GOCOVER_COBERTURA_VERSION' "$(ci_file go)")" bash -e -c "$conv" 2>&1) \
        || { echo "conversion step failed"; return 1; }
    echo "$d"
}
go_gate() { run_ci_gate "$1" go; }

@test "coverage-langs: go — CI 변환 단계(gocover-cobertura) + 게이트 단계가 바뀐 줄 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    require_tool go
    run edge_over go_gate go_change
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# ── typescript: lcov in the vitest coverage-v8 shape — SF relative to the project root ─────────────────
lcov_change() { # file report K → dir: <file> gets 100 new lines, the first K hit
    local d i
    d="$(gate_repo "$2")"
    mkdir -p "$d/$(dirname "$1")" "$d/$(dirname "$2")"
    for i in $(seq 1 100); do echo "// line $i"; done > "$d/$1"
    commit_all "$d"
    { echo "SF:$1"; for i in $(seq 1 100); do echo "DA:$i,$(( i <= $3 ? 1 : 0 ))"; done
      echo "LF:100"; echo "LH:$3"; echo "end_of_record"; } > "$d/$2"
    echo "$d"
}
ts_change() { lcov_change src/m.ts coverage/lcov.info "$1"; }
ts_gate() { run_ci_gate "$1" typescript; }

@test "coverage-langs: typescript — CI 게이트 단계가 vitest lcov 로 바뀐 줄 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    run edge_over ts_gate ts_change
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage-langs: CI 3개 언어 — PR 에서만, 전체 이력을 받은 체크아웃에서, 테스트 단계가 쓴 리포트로 게이트를 돈다" {
    run wiring_ci
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# Line number (1-based) of a step name in the test job, empty when missing.
step_index() { # workflow name
    yq -r '.jobs.test.steps[].name' "$1" | grep -nxF -- "$2" | cut -d: -f1 | head -1
}

wiring_ci() {
    local l f rep producer a b
    for l in python go typescript; do
        f="$(ci_file "$l")"
        case "$l" in
            python) rep="coverage.xml"; producer="Run tests with coverage" ;;
            go) rep="coverage.xml"; producer="Convert coverage to Cobertura" ;;
            typescript) rep="coverage/lcov.info"; producer="Run tests with coverage" ;;
        esac
        [ "$(yq -r '.jobs.test.steps[] | select(.uses // "" | test("^actions/checkout@")) | .with."fetch-depth"' "$f")" = "0" ] \
            || { echo "$l: test job checkout is not fetch-depth: 0 — the base branch is missing"; return 1; }
        a="$(step_index "$f" "$producer")"; b="$(step_index "$f" "$STEP")"
        [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || { echo "$l: \"$STEP\" is missing or not after \"$producer\""; return 1; }
        [ "$(S="$STEP" yq -r '.jobs.test.steps[] | select(.name == strenv(S)) | .if' "$f")" = "github.event_name == 'pull_request'" ] \
            || { echo "$l: the gate step is not limited to pull requests"; return 1; }
        [ "$(S="$STEP" yq -r '.jobs.test.steps[] | select(.name == strenv(S)) | .env.BASE_REF' "$f")" = '${{ github.base_ref }}' ] \
            || { echo "$l: BASE_REF is not github.base_ref"; return 1; }
        grep -qF "bash scripts/coverage-gate.sh $rep --compare-branch \"origin/\$BASE_REF\"" <<< "$(step_run "$f" "$STEP")" \
            || { echo "$l: the gate step does not read $rep against origin/\$BASE_REF"; return 1; }
        ! grep -qF '${{' <<< "$(step_run "$f" "$STEP")" || { echo "$l: \${{ }} inlined into the gate run: (template injection)"; return 1; }
    done
    grep -qF -- '--cov-report=xml:coverage.xml' <<< "$(step_run "$(ci_file python)" "Run tests with coverage")" \
        || { echo "python: the test step does not write coverage.xml"; return 1; }
    grep -qF '"lcov"' "$REPO_ROOT/typescript-react/templates/vitest.config.ts" || { echo "vitest.config.ts has no lcov reporter"; return 1; }
    grep -qF 'gocover-cobertura@${GOCOVER_COBERTURA_VERSION}' <<< "$(step_run "$(ci_file go)" "Convert coverage to Cobertura")" \
        || { echo "go: conversion does not use the pinned GOCOVER_COBERTURA_VERSION"; return 1; }
}

# ── hook languages ───────────────────────────────────────────────────────────────────────────────────────
# Runs the template hook coverage-gate (copied verbatim) at the pre-push stage.
hook_gate() { # dir lang
    H=coverage-gate yq '{"repos": [{"repo": "local", "hooks": [.repos[].hooks[] | select(.id == strenv(H))]}]}' \
        "$(hook_config "$2")" > "$1/.pre-commit-config.yaml"
    (cd "$1" && git add -A && PRE_COMMIT_HOME="$1/.cache/pre-commit" \
        pre-commit run coverage-gate --all-files --hook-stage pre-push 2>&1)
}
dart_change() { lcov_change lib/fixture.dart coverage/lcov.info "$1"; }
dart_gate() { hook_gate "$1" flutter-dart; }

@test "coverage-langs: dart — pre-push 훅 coverage-gate 가 Flutter lcov 로 바뀐 줄 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    require_tool pre-commit
    run edge_over dart_gate dart_change
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage-langs: 훅 3개 언어 — 리포트를 만드는 pre-push 훅 바로 뒤에, 같은 파일 조건으로, 그 리포트를 읽는 coverage-gate 훅이 있다" {
    run wiring_hooks
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

wiring_hooks() {
    local l c producer rep ids
    for l in csharp-dotnet flutter-dart ruby-rails; do
        c="$(hook_config "$l")"
        case "$l" in
            csharp-dotnet) producer=dotnet-test; rep='coverage.cobertura.xml' ;;
            flutter-dart) producer=flutter-test; rep='coverage/lcov.info' ;;
            ruby-rails) producer=rspec; rep='coverage/coverage.xml' ;;
        esac
        ids="$(yq -r '[.repos[].hooks[].id] | join(" ")' "$c")"
        [[ " $ids " == *" $producer coverage-gate "* ]] || { echo "$l: coverage-gate does not follow $producer ($ids)"; return 1; }
        [ "$(yq -r '.repos[].hooks[] | select(.id == "coverage-gate") | .stages | join(",")' "$c")" = "pre-push" ] \
            || { echo "$l: coverage-gate is not a pre-push hook"; return 1; }
        [ "$(P="$producer" yq -o json -I0 '.repos[].hooks[] | select(.id == strenv(P)) | [.files, .types, .types_or]' "$c")" \
          = "$(yq -o json -I0 '.repos[].hooks[] | select(.id == "coverage-gate") | [.files, .types, .types_or]' "$c")" ] \
            || { echo "$l: coverage-gate file filters differ from $producer"; return 1; }
        yq -r '.repos[].hooks[] | select(.id == "coverage-gate") | .entry' "$c" | grep -qF "scripts/coverage-gate.sh" \
            || { echo "$l: coverage-gate does not call scripts/coverage-gate.sh"; return 1; }
        yq -r '.repos[].hooks[] | select(.id == "coverage-gate") | .entry' "$c" | grep -qF "$rep" \
            || { echo "$l: coverage-gate does not read $rep"; return 1; }
    done
    yq -r '.repos[].hooks[] | select(.id == "dotnet-test") | .entry' "$(hook_config csharp-dotnet)" \
        | grep -qF -- '-p:CoverletOutputFormat=cobertura' || { echo "dotnet-test does not write Cobertura"; return 1; }
    grep -qF 'SimpleCov::Formatter::CoberturaFormatter' "${TPL_ROOT:-$REPO_ROOT}/ruby-rails/templates/.simplecov" \
        || { echo ".simplecov does not write Cobertura"; return 1; }
}

@test "coverage-langs: 6개 언어 bootstrap 이 게이트를 scripts/ 로 복사한다" {
    local l
    for l in python go typescript-react csharp-dotnet flutter-dart ruby-rails; do
        grep -qF 'cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh' "$REPO_ROOT/$l/bootstrap.sh" \
            || { echo "$l: bootstrap does not copy the gate"; return 1; }
    done
}

@test "coverage-langs: 장부 — 10개 언어 모두 커버리지 칸이 게이트를 가리키고, 6개 언어는 전체 한도 검사(✓·script)를 그대로 둔다" {
    local l
    for l in go typescript python rust java kotlin csharp dart swift ruby; do
        L="$l" yq -r '.languages[strenv(L)].coverage.tool' "$THRESHOLDS" | grep -qF 'coverage-gate' \
            || { echo "$l.coverage tool does not name the gate"; return 1; }
    done
    for l in go typescript python csharp ruby; do
        [ "$(L="$l" yq -r '.languages[strenv(L)].coverage.cell' "$THRESHOLDS")" = "✓" ] || { echo "$l.coverage cell is no longer ✓"; return 1; }
    done
    [ "$(yq -r '.languages.dart.coverage.cell' "$THRESHOLDS")" = "script" ] || { echo "dart.coverage cell is no longer script"; return 1; }
}

@test "coverage-langs: 반증 — 리포트 경로를 틀리게 · 게이트 단계를 PR 밖으로 · 훅 순서를 뒤집은 템플릿 복사본에서는 위 검사가 실패한다" {
    require_gate_tools
    local out l
    export CI_DIR TPL_ROOT
    CI_DIR="$(mktemp -d -p "$BATS_TEST_TMPDIR")"; TPL_ROOT="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp "$REPO_ROOT"/common/ci-templates/ci-*.yml "$CI_DIR/"
    for l in csharp-dotnet flutter-dart ruby-rails typescript-react; do mkdir -p "$TPL_ROOT/$l"; cp -R "$REPO_ROOT/$l/templates" "$TPL_ROOT/$l/"; done
    # 1. the CI gate reads a report the test step does not write → the edge run fails (report not found)
    sed_i 's#bash scripts/coverage-gate.sh coverage/lcov.info#bash scripts/coverage-gate.sh coverage/lcov.json#' "$CI_DIR/ci-typescript.yml"
    run edge_over ts_gate ts_change
    grep -qF "edge rejected" <<< "$output" || { echo "wrong report path not caught: $output"; return 1; }
    cp "$REPO_ROOT/common/ci-templates/ci-typescript.yml" "$CI_DIR/"
    # 2. the gate step on every event → the wiring check fails
    sed_i "s/if: github.event_name == 'pull_request'/if: always()/" "$CI_DIR/ci-typescript.yml"
    run wiring_ci
    [ "$status" -ne 0 ] && grep -qF "not limited to pull requests" <<< "$output" || { echo "gate on every event not caught: $output"; return 1; }
    # 3. coverage-gate before the hook that writes the report → the wiring check fails
    out="$TPL_ROOT/flutter-dart/templates/.pre-commit-config.yaml"
    yq -i '(.repos[] | select(.hooks[].id == "coverage-gate") | .hooks) |= ([.[] | select(.id == "coverage-gate")] + [.[] | select(.id != "coverage-gate")])' "$out"
    run wiring_hooks
    [ "$status" -ne 0 ] && grep -qF "coverage-gate does not follow flutter-test" <<< "$output" || { echo "hook order not caught: $output"; return 1; }
}
