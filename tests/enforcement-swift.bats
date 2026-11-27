#!/usr/bin/env bats
# tests/enforcement-swift.bats — Swift 템플릿의 크기 수치가 실제로 막히는지 실행 결과로 판정 (로드맵 3단계).
# tests/enforcement.bats 와 같은 방식: edge(한도 = 통과) · over(한도 + 1 = 실패) fixture 를 만들고
# swift/templates 의 .swiftlint.yml 과 pre-commit 훅 swiftlint(`swiftlint lint --strict`)를 그대로 실행한다.
#   --strict 는 warning 도 실패로 만든다 — 그래서 실제 한도는 warning 숫자다(템플릿은 warning = error)
#   복잡도 — SwiftLint cyclomatic_complexity (≈: SwiftLint 값 = 분기 수, 1 을 더하지 않고 ?: · && · || 를 세지 않는다.
#     ignores_case_statements: true 라 case 도 빠진다). 정본 "1 + 분기 ≤ 15" = SwiftLint 값 ≤ 14
#   함수 길이 — function_body_length (중괄호 안, 주석·빈 줄 제외) · 파일 길이 — file_length (주석·빈 줄 제외)
#   커버리지 — Swift 템플릿에 테스트·커버리지 훅도 CI 템플릿도 없다 → 로드맵 3단계 A7 에서
# swiftlint: PATH 의 swiftlint 또는 SWIFTLINT(실행 파일 경로). 리눅스는 Swift 툴체인의 SourceKit 이 필요하다 —
#   LINUX_SOURCEKIT_LIB_PATH(…/usr/lib) 가 없으면 PATH 의 swift 에서 찾는다.

load helpers

THRESHOLDS="$REPO_ROOT/common/quality-thresholds.yaml"
SW_TPL="$REPO_ROOT/swift/templates"

setup() {
    require_tool yq
}

limit() { # metric
    M="$1" yq -r '.languages.swift[strenv(M)].limit // .thresholds[strenv(M)]' "$THRESHOLDS"
}

require_swiftlint() {
    require_tool "${SWIFTLINT:-swiftlint}"
    require_tool pre-commit
    PATH="$(dirname "$(command -v "${SWIFTLINT:-swiftlint}")"):$PATH"
    export PATH
    if [ "$(uname -s)" = "Linux" ] && [ -z "${LINUX_SOURCEKIT_LIB_PATH:-}" ]; then
        command -v swift >/dev/null 2>&1 || {
            [ "${TEMPLATE_TOOLS_REQUIRED:-0}" = "1" ] && { echo "required tool missing: swift (SourceKit)" >&2; return 1; }
            skip "no Swift toolchain (SourceKit) for swiftlint"
        }
        LINUX_SOURCEKIT_LIB_PATH="$(dirname "$(readlink -f "$(command -v swift)")")/../lib"
        export LINUX_SOURCEKIT_LIB_PATH
    fi
}

# A package-shaped directory with the template .swiftlint.yml, inside a git repo; prints its path.
sw_proj() {
    local dir
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    mkdir -p "$dir/Sources/Fx"
    cp "$SW_TPL/.swiftlint.yml" "$dir/"
    git -C "$dir" init -q
    echo "$dir"
}

# Runs one local hook of the template pre-commit config (copied verbatim, nothing else) on every file.
hook_rc() { # dir hook-id
    H="$2" yq '{"repos": [{"repo": "local", "hooks": [.repos[].hooks[] | select(.id == strenv(H))]}]}' \
        "$SW_TPL/.pre-commit-config.yaml" > "$1/.pre-commit-config.yaml"
    (cd "$1" && git add -A && PRE_COMMIT_HOME="$1/.cache/pre-commit" pre-commit run "$2" --all-files 2>&1)
}
hook_lint() { hook_rc "$1" swiftlint; }
hook_file_size() { hook_rc "$1" file-size-limit; }

src() { cat > "$1/Sources/Fx/Fixture.swift"; }

head_doc() { printf '/// Adds.\npublic func %s(_ value: Int, _ step: Int) -> Int {\n    var result = value\n' "$1"; }

# Complexity N in the standard's terms (1 + branches): N - 1 one-line `if`s.
sw_complexity_fn() { # name N
    local i
    head_doc "$1"
    for i in $(seq 1 $(( $2 - 1 ))); do printf '    if result > step { result -= step }\n'; done
    printf '    return result\n}\n'
}

# A function whose body (between the braces) has N code lines; one blank and two comment lines are added on top.
sw_lines_fn() { # name N
    local i
    head_doc "$1"
    printf '\n    // not counted\n    // not counted\n'
    for i in $(seq 1 $(( $2 - 2 ))); do printf '    result += step\n'; done
    printf '    return result\n}\n'
}

# A file of N lines, every one of them code (file_length skips comment and blank lines).
sw_file_n() { # dir N
    local i
    for i in $(seq 1 "$2"); do printf 'let value%d = %d\n' "$i" "$i"; done > "$1/Sources/Fx/Fixture.swift"
}

# N physical lines of which 20 are comments — SwiftLint file_length sees N - 20, the hook sees N.
sw_file_commented_n() { # dir N
    local i
    { for i in $(seq 1 20); do printf '// note %d\n' "$i"; done
      for i in $(seq 1 $(( $2 - 20 ))); do printf 'let value%d = %d\n' "$i" "$i"; done; } > "$1/Sources/Fx/Fixture.swift"
}

w_complexity_edge() { sw_complexity_fn edge "$(limit complexity)" | src "$1"; }
w_complexity_over() { sw_complexity_fn over $(( $(limit complexity) + 1 )) | src "$1"; }
w_lines_edge() { sw_lines_fn edge "$(limit function_lines)" | src "$1"; }
w_lines_over() { sw_lines_fn over $(( $(limit function_lines) + 1 )) | src "$1"; }
w_file_edge() { sw_file_n "$1" "$(limit file_lines)"; }
w_file_over() { sw_file_n "$1" $(( $(limit file_lines) + 1 )); }
w_pfile_edge() { sw_file_commented_n "$1" "$(limit file_lines)"; }
w_pfile_over() { sw_file_commented_n "$1" $(( $(limit file_lines) + 1 )); }

# edge must pass (exit 0, and no "Invalid configuration" warning); over must fail and print the expected marker.
sw_check() { # runner(dir) edge-writer over-writer expected-over-message
    local e o out rc
    e="$(sw_proj)"; o="$(sw_proj)"
    "$2" "$e"; "$3" "$o"
    out="$("$1" "$e")" || { echo "edge rejected: $out"; return 1; }
    ! grep -q 'Invalid configuration' <<< "$out" || { echo "config warning: $out"; return 1; }
    rc=0; out="$("$1" "$o")" || rc=$?
    [ "$rc" -ne 0 ] || { echo "over accepted (exit 0): $out"; return 1; }
    grep -qF -- "$4" <<< "$out" || { echo "over: expected [$4] in: $out"; return 1; }
}

@test "swift: 복잡도 — 1+분기 한도(정본) 함수는 훅 swiftlint(--strict)를 통과, 한도+1 은 막힌다" {
    require_swiftlint
    run sw_check hook_lint w_complexity_edge w_complexity_over \
        "currently complexity is $(limit complexity)"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "swift: 함수 길이 — 중괄호 안 한도(정본) 줄은 주석·빈 줄이 더 있어도 통과, 한도+1 줄은 막힌다" {
    require_swiftlint
    run sw_check hook_lint w_lines_edge w_lines_over \
        "should span $(limit function_lines) lines or less excluding comments and whitespace: currently spans $(( $(limit function_lines) + 1 )) lines"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "swift: 파일 길이 — 한도(정본) 줄 파일은 통과, 한도+1 줄은 file_length 가 막는다" {
    require_swiftlint
    run sw_check hook_lint w_file_edge w_file_over \
        "File should contain $(limit file_lines) lines or less excluding comments and whitespaces: currently contains $(( $(limit file_lines) + 1 ))"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "swift: 파일 길이(물리 줄) — 주석이 섞인 한도(정본) 줄 파일은 통과, 한도+1 줄은 file-size-limit 훅이 막는다" {
    require_tool pre-commit
    run sw_check hook_file_size w_pfile_edge w_pfile_over \
        "FAIL: Sources/Fx/Fixture.swift ($(( $(limit file_lines) + 1 )) lines, max $(limit file_lines))"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "swift: .swiftlint.yml 의 warning = error = 정본(복잡도는 정본-1)이고, 훅이 --strict 다" {
    local y="$SW_TPL/.swiftlint.yml" r want
    for r in "cyclomatic_complexity|$(( $(limit complexity) - 1 ))" "function_body_length|$(limit function_lines)" "file_length|$(limit file_lines)"; do
        want="${r#*|}"
        R="${r%%|*}" yq -e '.[strenv(R)].warning == '"$want"' and .[strenv(R)].error == '"$want" "$y" >/dev/null \
            || { echo "${r%%|*} warning/error are not both $want"; return 1; }
    done
    yq -r '.repos[].hooks[] | select(.id == "swiftlint") | .entry' "$SW_TPL/.pre-commit-config.yaml" | grep -qF -- '--strict' \
        || { echo "swiftlint hook lost --strict"; return 1; }
}

@test "swift: 장부 — 복잡도 ≈ · 함수·파일 ✓ · 커버리지 script(coverage-gate)" {
    [ "$(yq -r '.languages.swift.complexity.cell' "$THRESHOLDS")" = "≈" ] || { echo "swift.complexity cell is not ≈"; return 1; }
    [ "$(yq -r '.languages.swift.function_lines.cell' "$THRESHOLDS")" = "✓" ] || { echo "swift.function_lines cell is not ✓"; return 1; }
    [ "$(yq -r '.languages.swift.file_lines.cell' "$THRESHOLDS")" = "✓" ] || { echo "swift.file_lines cell is not ✓"; return 1; }
    [ "$(yq -r '.languages.swift.coverage.cell' "$THRESHOLDS")" = "script" ] || { echo "swift.coverage cell is not script"; return 1; }
}

# A copy of the templates with one edit applied; prints the copy's path.
broken_tpl() { # file sed-expression
    local dir
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp -a "$SW_TPL/." "$dir/"
    sed_i -e "$2" "$dir/$1"
    ! cmp -s "$SW_TPL/$1" "$dir/$1" || { echo "broken variant did not change $1: $2" >&2; return 1; }
    echo "$dir"
}

@test "swift: 반증 — 고장 난 설정 5종(warning·error 한도 +1 3 · --strict 제거 · 옛 warning 10)에서는 위 검사가 실패한다" {
    require_swiftlint
    local v file sed_expr w why c l f
    c="$(( $(limit complexity) - 1 ))"; l="$(limit function_lines)"; f="$(limit file_lines)"
    for v in ".swiftlint.yml|/^cyclomatic_complexity:/,/error/s/: $c\$/: $(( c + 1 ))/|w_complexity_edge w_complexity_over|over accepted" \
             ".swiftlint.yml|/^function_body_length:/,/error/s/: $l\$/: $(( l + 1 ))/|w_lines_edge w_lines_over|over accepted" \
             ".swiftlint.yml|/^file_length:/,/error/s/: $f\$/: $(( f + 1 ))/|w_file_edge w_file_over|over accepted" \
             ".pre-commit-config.yaml|s/swiftlint lint --strict /swiftlint lint /|w_lines_edge w_lines_over|over accepted" \
             ".swiftlint.yml|/^cyclomatic_complexity:/,/error/s/warning: $c\$/warning: 10/|w_complexity_edge w_complexity_over|edge rejected"; do
        IFS='|' read -r file sed_expr w why <<< "$v"
        SW_TPL="$(broken_tpl "$file" "$sed_expr")" || return 1
        if [ "$file" = ".pre-commit-config.yaml" ]; then
            # without --strict only `error` fails the run — move the error threshold up so the warning alone decides
            sed_i "/^function_body_length:/,/error/s/error: $l\$/error: $(( l + 10 ))/" "$SW_TPL/.swiftlint.yml"
        fi
        # shellcheck disable=SC2086 # w holds two writer names
        run sw_check hook_lint $w "_"
        [ "$status" -ne 0 ] && grep -qF "$why" <<< "$output" \
            || { echo "check not broken the expected way ($why) by: $file $sed_expr — $output"; return 1; }
        SW_TPL="$REPO_ROOT/swift/templates"
    done
}
