#!/usr/bin/env bats
# tests/enforcement-coverage.bats — 공용 커버리지 게이트(common/testing-templates/coverage-gate.sh)가 실제로 막는지 판정
# (로드맵 3단계 A7). 정본 커버리지 칸 = 「바뀐 줄 80%(diff-cover) + 전체는 기준선 아래로 떨어지지 않음(ratchet)」.
# 실제 git 저장소에서 main 대비 100줄을 바꾸고 그중 K줄이 실행된 리포트(lcov · JaCoCo)를 만들어 게이트를 돌린다:
#   edge K = 한도(80) → 통과 · over K = 한도-1 → 실패. ratchet 은 기준선 파일 이상이면 통과, 아래면 실패.
# 이 게이트를 pre-push 훅으로 부르는 언어: rust · java-spring · kotlin-spring · swift (장부 coverage 칸 script).
# 전체 80% 검사와 함께 쓰는 6개 언어(python · go · typescript-react · csharp-dotnet · flutter-dart · ruby-rails)의 연결은
#   tests/enforcement-coverage-langs.bats · enforcement-csharp.bats · enforcement-ruby.bats.
# 리포트를 만드는 언어 도구(cargo llvm-cov · Gradle JaCoCo · swift test + llvm-cov export)는 여기서 실행하지 않는다.
# diff-cover 는 게이트가 고정 버전으로 uvx(또는 pipx run)로 실행한다 — uv 가 필요하다.

load helpers

THRESHOLDS="$REPO_ROOT/common/quality-thresholds.yaml"
GATE="$REPO_ROOT/common/testing-templates/coverage-gate.sh"
GATE_LANGS="rust java-spring kotlin-spring swift"

setup() {
    require_tool yq
}

limit() { yq -r '.thresholds.coverage' "$THRESHOLDS"; }

require_gate_tools() {
    require_tool git
    require_tool python3
    command -v uvx >/dev/null 2>&1 || require_tool pipx
}

# A repo whose `feature` branch adds 100 lines to <file> on top of main; prints its path.
cov_repo() { # file
    local dir i
    # resolved path: diff-cover matches absolute report paths against the resolved working directory
    # (macOS mktemp gives /var/..., a symlink to /private/var/...)
    dir="$(cd "$(mktemp -d -p "$BATS_TEST_TMPDIR")" && pwd -P)"
    git -C "$dir" init -q -b main
    mkdir -p "$dir/$(dirname "$1")"
    echo "// base" > "$dir/$1"
    git -C "$dir" add -A && git -C "$dir" -c user.email=t@t -c user.name=t commit -qm base
    git -C "$dir" switch -qc feature
    for i in $(seq 1 100); do echo "// change $i"; done >> "$dir/$1"
    git -C "$dir" -c user.email=t@t -c user.name=t commit -qam change
    echo "$dir"
}

# lcov for src/lib.rs: line 1 (base) hit, changed lines 2..101 — the first K hit.
lcov_k() { # dir K
    local i
    { echo "SF:src/lib.rs"; echo "DA:1,1"
      for i in $(seq 2 101); do echo "DA:$i,$(( i - 1 <= $2 ? 1 : 0 ))"; done
      echo "LF:101"; echo "LH:$(( $2 + 1 ))"; echo "end_of_record"; } > "$1/lcov.info"
}

# JaCoCo for <JACOCO_FILE> (default src/main/java/fx/A.java — package fx), same shape.
jacoco_k() { # dir K
    local i c
    { echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><report name=\"fx\"><package name=\"fx\"><sourcefile name=\"$(basename "${JACOCO_FILE:-A.java}")\">"
      echo '<line nr="1" mi="0" ci="1" mb="0" cb="0"/>'
      for i in $(seq 2 101); do c=$(( i - 1 <= $2 ? 1 : 0 )); echo "<line nr=\"$i\" mi=\"$(( 1 - c ))\" ci=\"$c\" mb=\"0\" cb=\"0\"/>"; done
      echo "<counter type=\"LINE\" missed=\"$(( 100 - $2 ))\" covered=\"$(( $2 + 1 ))\"/></sourcefile></package>"
      echo "<counter type=\"LINE\" missed=\"$(( 100 - $2 ))\" covered=\"$(( $2 + 1 ))\"/></report>"; } > "$1/jacoco.xml"
}

gate() { # dir report [args…]
    local d="$1"; shift
    (cd "$d" && bash "$GATE" "$@" --compare-branch main 2>&1)
}

# edge must pass (exit 0); over must fail and print the expected marker.
gate_check() { # file report-writer report-name
    local e o out rc
    e="$(cov_repo "$1")"; o="$(cov_repo "$1")"
    "$2" "$e" "$(limit)"; "$2" "$o" $(( $(limit) - 1 ))
    out="$(gate "$e" "$3")" || { echo "edge rejected: $out"; return 1; }
    rc=0; out="$(gate "$o" "$3")" || rc=$?
    [ "$rc" -ne 0 ] || { echo "over accepted (exit 0): $out"; return 1; }
    grep -qF "FAIL: changed-line coverage is below $(limit)%" <<< "$out" || { echo "over: unexpected output: $out"; return 1; }
}

@test "coverage: 바뀐 줄 — lcov 리포트에서 한도(정본)%는 통과, 한도-1 %는 게이트가 막는다" {
    require_gate_tools
    run gate_check src/lib.rs lcov_k lcov.info
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage: 바뀐 줄 — JaCoCo 리포트에서 한도(정본)%는 통과, 한도-1 %는 게이트가 막는다" {
    require_gate_tools
    run gate_check src/main/java/fx/A.java jacoco_k jacoco.xml
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage: 바뀐 줄 — Kotlin(src/main/kotlin) JaCoCo 리포트도 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    JACOCO_FILE=A.kt run gate_check src/main/kotlin/fx/A.kt jacoco_k jacoco.xml
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage: 리포트의 파일이 저장소에 하나도 없으면(경로 불일치) 통과가 아니라 실패한다" {
    require_gate_tools
    local d out
    d="$(cov_repo src/lib.rs)"
    printf 'SF:src/other.rs\nDA:1,1\nLF:1\nLH:1\nend_of_record\n' > "$d/lcov.info"
    out="$(gate "$d" lcov.info)" && { echo "a report that covers none of the changed lines passed: $out"; return 1; }
    grep -qF "FAIL: no file of lcov.info exists in the repository" <<< "$out" || { echo "unexpected: $out"; return 1; }
}

@test "coverage: 리포트 여러 개 중 하나라도 저장소 파일을 하나도 가리키지 않으면, 다른 리포트가 맞아도 실패한다" {
    require_gate_tools
    local d out i
    d="$(cov_repo src/b.rs)"   # the change: 100 untested lines in src/b.rs
    echo "// a" > "$d/src/a.rs"
    printf 'SF:src/a.rs\nDA:1,1\nend_of_record\n' > "$d/a.info"
    { echo "SF:wrong/b.rs"; for i in $(seq 1 101); do echo "DA:$i,0"; done; echo "end_of_record"; } > "$d/b.info"
    out="$(gate "$d" a.info b.info)" && { echo "a mismatched second report let untested lines pass: $out"; return 1; }
    grep -qF "FAIL: no file of b.info exists in the repository" <<< "$out" || { echo "unexpected: $out"; return 1; }
    # a report with no source file at all (a test project that covers nothing) is not a mismatch
    # (same format as the good report — diff-cover does not mix lcov and XML)
    d="$(cov_repo src/fx/a.py)"; cobertura_k "$d" 100 good.xml
    printf '<?xml version="1.0" ?><coverage><sources><source>%s</source></sources><packages/></coverage>\n' "$d" > "$d/empty.xml"
    out="$(gate "$d" good.xml empty.xml)" || { echo "an empty report next to a good one was rejected: $out"; return 1; }
}

# A repo whose `feature` branch changes only README.md and a test file; src/lib.rs (in the report) stays as on main.
docs_only_repo() {
    local dir
    # resolved path: diff-cover matches absolute report paths against the resolved working directory
    # (macOS mktemp gives /var/..., a symlink to /private/var/...)
    dir="$(cd "$(mktemp -d -p "$BATS_TEST_TMPDIR")" && pwd -P)"
    git -C "$dir" init -q -b main
    mkdir -p "$dir/src" "$dir/tests"
    echo "// base" > "$dir/src/lib.rs"; echo "base" > "$dir/README.md"
    git -C "$dir" add -A && git -C "$dir" -c user.email=t@t -c user.name=t commit -qm base
    git -C "$dir" switch -qc feature
    echo "more" >> "$dir/README.md"; echo "// test" > "$dir/tests/t.rs"
    git -C "$dir" add -A && git -C "$dir" -c user.email=t@t -c user.name=t commit -qm docs
    printf 'SF:src/lib.rs\nDA:1,1\nLF:1\nLH:1\nend_of_record\n' > "$dir/lcov.info"
    echo "$dir"
}

@test "coverage: 바뀐 줄이 리포트의 측정 줄에 하나도 없으면(문서·테스트만 바꿈) 알리고 통과한다" {
    require_gate_tools
    local d out
    d="$(docs_only_repo)"
    out="$(gate "$d" lcov.info)" || { echo "a docs/tests-only change was blocked: $out"; return 1; }
    grep -qF "coverage-gate: the report measures none of the changed lines" <<< "$out" || { echo "missing notice: $out"; return 1; }
}

# Cobertura for src/fx/a.py in the coverage.py · gocover-cobertura · coverlet shape: an absolute <source> and a
# filename relative to it. Line 1 (base) hit; of the changed lines 2..101, K lines from <from> (default 2) are hit.
cobertura_k() { # dir K [report=coverage.xml] [from=2]
    local i from="${4:-2}"
    { echo "<?xml version=\"1.0\" ?><coverage><sources><source>$1/src</source></sources><packages><package name=\"fx\"><classes><class name=\"a.py\" filename=\"fx/a.py\"><lines>"
      echo '<line number="1" hits="1"/>'
      for i in $(seq 2 101); do echo "<line number=\"$i\" hits=\"$(( i >= from && i < from + $2 ? 1 : 0 ))\"/>"; done
      echo "</lines></class></classes></package></packages></coverage>"; } > "$1/${3:-coverage.xml}"
}

@test "coverage: 바뀐 줄 — Cobertura 리포트(절대 source + 상대 filename)에서 한도(정본)%는 통과, 한도-1 %는 막는다" {
    require_gate_tools
    run gate_check src/fx/a.py cobertura_k coverage.xml
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "coverage: 리포트 여러 개(테스트 프로젝트마다 하나) — 합친 결과로 판정하고, 리포트를 하나도 받지 못하면 실패한다" {
    require_gate_tools
    run union_check
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# Two Cobertura reports covering different halves of the changed lines: together at the limit pass, below fail.
union_check() {
    local d out h
    h=$(( $(limit) / 2 ))
    d="$(cov_repo src/fx/a.py)"
    cobertura_k "$d" "$h" a.xml 2; cobertura_k "$d" $(( $(limit) - h )) b.xml $(( 2 + h ))
    out="$(gate "$d" a.xml b.xml)" || { echo "two reports that together reach the limit were rejected: $out"; return 1; }
    out="$(gate "$d" a.xml b.xml --write-baseline)" || { echo "--write-baseline failed: $out"; return 1; }
    # union, not sum: 1 + limit of 101 lines hit
    [ "$(cat "$d/.coverage-baseline")" = "$(python3 -c "print(f'{($(limit) + 1) * 100 / 101:.2f}')")" ] \
        || { echo "total of two reports is [$(cat "$d/.coverage-baseline")]"; return 1; }
    rm "$d/.coverage-baseline"
    cobertura_k "$d" $(( $(limit) - h - 1 )) b.xml $(( 2 + h ))
    out="$(gate "$d" a.xml b.xml)" && { echo "two reports below the limit together were accepted: $out"; return 1; }
    grep -qF "FAIL: changed-line coverage is below $(limit)%" <<< "$out" || { echo "unexpected: $out"; return 1; }
    out="$(cd "$d" && bash "$GATE" --compare-branch main 2>&1)" && { echo "no report accepted: $out"; return 1; }
    grep -qF "FAIL: no coverage report given" <<< "$out" || { echo "unexpected: $out"; return 1; }
}

@test "coverage: 비교 브랜치가 없거나 기준선 값이 숫자 0..100 이 아니면 원인을 밝히고 실패한다" {
    require_gate_tools
    local d out v
    d="$(cov_repo src/lib.rs)"; lcov_k "$d" 100
    out="$(cd "$d" && bash "$GATE" lcov.info --compare-branch no-such-branch 2>&1)" && { echo "missing compare branch passed"; return 1; }
    grep -qF "FAIL: compare branch not found: no-such-branch" <<< "$out" || { echo "unexpected: $out"; return 1; }
    for v in abc -5 101 ""; do
        printf '%s\n' "$v" > "$d/.coverage-baseline"
        out="$(gate "$d" lcov.info)" && { echo "baseline [$v] accepted: $out"; return 1; }
        grep -qF "FAIL: invalid baseline" <<< "$out" || { echo "baseline [$v]: unexpected: $out"; return 1; }
    done
}

@test "coverage: ratchet — 전체가 기준선 이상이면 통과, 아래면 막고, 기준선이 없으면 알리고 넘어간다" {
    require_gate_tools
    local d out
    d="$(cov_repo src/lib.rs)"; lcov_k "$d" 100          # every changed line hit; total 101/101 = 100.00 %
    out="$(gate "$d" lcov.info)" || { echo "no baseline should pass: $out"; return 1; }
    grep -qF "total-coverage ratchet skipped" <<< "$out" || { echo "missing no-baseline notice: $out"; return 1; }
    out="$(gate "$d" lcov.info --write-baseline)" || { echo "--write-baseline failed: $out"; return 1; }
    [ "$(cat "$d/.coverage-baseline")" = "100.00" ] || { echo "baseline file is [$(cat "$d/.coverage-baseline")]"; return 1; }
    out="$(gate "$d" lcov.info)" || { echo "equal to baseline should pass: $out"; return 1; }
    lcov_k "$d" "$(limit)"                                 # changed lines still >= limit, total drops to 81/101
    out="$(gate "$d" lcov.info)" && { echo "drop below baseline accepted: $out"; return 1; }
    grep -qF "FAIL: total coverage 80.20% dropped below the baseline 100.00%" <<< "$out" || { echo "unexpected: $out"; return 1; }
}

@test "coverage: 리포트가 없으면 실패한다" {
    require_gate_tools
    local d out
    d="$(cov_repo src/lib.rs)"
    out="$(gate "$d" missing.info)" && { echo "missing report accepted: $out"; return 1; }
    grep -qF "FAIL: coverage report not found: missing.info" <<< "$out" || { echo "unexpected: $out"; return 1; }
}

@test "coverage: 게이트를 쓰는 4개 언어의 pre-push 훅이 리포트를 만든 뒤 게이트를 부르고, bootstrap 이 게이트를 복사한다" {
    local l ent
    for l in $GATE_LANGS; do
        ent="$(yq -r '.repos[].hooks[] | select(.id == "coverage-gate") | .entry' "$REPO_ROOT/$l/templates/.pre-commit-config.yaml")"
        [ -n "$ent" ] || { echo "$l: no coverage-gate hook"; return 1; }
        grep -qF "scripts/coverage-gate.sh " <<< "$ent" || { echo "$l: coverage-gate hook does not call scripts/coverage-gate.sh"; return 1; }
        [ "$(yq -r '.repos[].hooks[] | select(.id == "coverage-gate") | .stages | join(",")' "$REPO_ROOT/$l/templates/.pre-commit-config.yaml")" = "pre-push" ] \
            || { echo "$l: coverage-gate is not a pre-push hook"; return 1; }
        grep -qF 'common/testing-templates/coverage-gate.sh' "$REPO_ROOT/$l/bootstrap.sh" || { echo "$l: bootstrap does not copy the gate"; return 1; }
    done
    grep -qE '^fail_under=80$' "$GATE" || { echo "gate default --fail-under is not 80"; return 1; }
}

@test "coverage: 장부 — 게이트 4개 언어의 커버리지 칸이 script 이고 게이트를 가리킨다" {
    local l k
    for l in rust java kotlin swift; do
        [ "$(L="$l" yq -r '.languages[strenv(L)].coverage.cell' "$THRESHOLDS")" = "script" ] || { echo "$l.coverage cell is not script"; return 1; }
        L="$l" yq -r '.languages[strenv(L)].coverage.tool' "$THRESHOLDS" | grep -qF 'coverage-gate' || { echo "$l.coverage tool does not name the gate"; return 1; }
    done
    k="$(yq -r '[.languages[][] | select(.cell == "pending")] | length' "$THRESHOLDS")"
    [ "$k" = "0" ] || { echo "$k pending cells left in the ledger"; return 1; }
}

# A copy of the gate with one edit applied; prints the copy's path.
broken_gate() { # sed-expression
    local f
    f="$(mktemp -p "$BATS_TEST_TMPDIR")"
    sed -e "$1" "$REPO_ROOT/common/testing-templates/coverage-gate.sh" > "$f"
    ! cmp -s "$REPO_ROOT/common/testing-templates/coverage-gate.sh" "$f" || { echo "broken variant did not change the gate: $1" >&2; return 1; }
    echo "$f"
}

@test "coverage: 반증 — 고장 난 게이트 8종(기본 한도 -1 · diff-cover 결과 무시 · 측정 줄 없음 허용 · 경로 판정 끔 · 경로 판정 항상 실패 · 첫 리포트만 · Java 전용 src-roots · ratchet 비교 무력화)에서는 위 검사가 실패한다" {
    require_gate_tools
    local d out
    GATE="$(broken_gate "s/^fail_under=80\$/fail_under=79/")" || return 1
    run gate_check src/lib.rs lcov_k lcov.info
    [ "$status" -ne 0 ] && grep -qF "over accepted" <<< "$output" || { echo "fail_under 79 not caught: $output"; return 1; }
    GATE="$(broken_gate 's/^elif \[ "\$rc" -ne 0 \]; then$/elif false; then/')" || return 1
    run gate_check src/lib.rs lcov_k lcov.info
    [ "$status" -ne 0 ] && grep -qF "over accepted" <<< "$output" || { echo "ignored diff-cover result not caught: $output"; return 1; }
    GATE="$(broken_gate 's/^if grep -qF .No lines with coverage information. <<< "\$dc_out"; then$/if false; then/')" || return 1
    d="$(docs_only_repo)"
    out="$(gate "$d" lcov.info)"
    ! grep -qF "the report measures none of the changed lines" <<< "$out" || { echo "without the no-lines branch the notice still printed — the variant did not disable it"; return 1; }
    GATE="$(broken_gate 's/^    if named and not resolved:$/    if False:/')" || return 1
    d="$(cov_repo src/lib.rs)"
    printf 'SF:src/other.rs\nDA:1,1\nLF:1\nLH:1\nend_of_record\n' > "$d/lcov.info"
    gate "$d" lcov.info >/dev/null || { echo "without the path check the mismatched report should pass — the variant did not disable it"; return 1; }
    GATE="$(broken_gate 's/^    if named and not resolved:$/    if True:/')" || return 1
    d="$(docs_only_repo)"
    gate "$d" lcov.info >/dev/null && { echo "a path check that always fails still let the docs-only change pass"; return 1; }
    GATE="$(broken_gate 's/"\${diff_cover\[@\]}" "\${reports\[@\]}"/"${diff_cover[@]}" "${reports[0]}"/')" || return 1
    run union_check
    [ "$status" -ne 0 ] || { echo "first-report-only gate not caught by the union check"; return 1; }
    GATE="$(broken_gate 's#^src_roots="src/main/java src/main/kotlin src/test/java src/test/kotlin"$#src_roots="src/main/java"#')" || return 1
    JACOCO_FILE=A.kt run gate_check src/main/kotlin/fx/A.kt jacoco_k jacoco.xml
    [ "$status" -ne 0 ] || { echo "Java-only src roots not caught for Kotlin"; return 1; }
    GATE="$REPO_ROOT/common/testing-templates/coverage-gate.sh"
    GATE="$(broken_gate "s/sys.exit(0 if float(sys.argv\[1\]) >= float(sys.argv\[2\]) else 1)/sys.exit(0)/")" || return 1
    d="$(cov_repo src/lib.rs)"; lcov_k "$d" 100
    gate "$d" lcov.info --write-baseline >/dev/null
    lcov_k "$d" "$(limit)"
    out="$(gate "$d" lcov.info)" || { echo "broken ratchet still failed — the variant did not disable it: $out"; return 1; }
    GATE="$REPO_ROOT/common/testing-templates/coverage-gate.sh"
    out="$(gate "$d" lcov.info)" && { echo "real gate accepted the drop: $out"; return 1; }
    true
}
