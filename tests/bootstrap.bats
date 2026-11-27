#!/usr/bin/env bats
# shellcheck shell=bash
# 언어 bootstrap — 레거시 훅 설정 제거 · husky 미설치 처리 · LANG 보존 · Gradle 감지 · pre-push 영수증 연동

load 'helpers'

LANGS="python kotlin-spring java-spring typescript-react go rust flutter-dart swift csharp-dotnet ruby-rails"

# 루트 bootstrap.sh 사본 + 언어별 스텁(실행된 언어와 자식이 본 LANG 을 출력) — 실제 설치를 돌리지 않고 분기만 본다
make_stub_dispatcher() {
    local ds="$BATS_TEST_TMPDIR/ds" l
    mkdir -p "$ds"
    cp "$REPO_ROOT/bootstrap.sh" "$ds/bootstrap.sh"
    for l in $LANGS; do
        mkdir -p "$ds/$l"
        printf '#!/usr/bin/env bash\necho "RAN=%s CHILD_LANG=${LANG:-}"\n' "$l" > "$ds/$l/bootstrap.sh"
    done
    echo "$ds"
}

# 픽스처 디렉터리를 만들고 경로를 출력한다 — 인자는 만들 파일 경로(디렉터리는 끝에 /)
make_fixture() {
    local dir p
    dir="$(mktemp -d "$BATS_TEST_TMPDIR/fx.XXXXXX")"
    for p in "$@"; do
        if [[ "$p" == */ ]]; then mkdir -p "$dir/$p"; else mkdir -p "$(dirname "$dir/$p")"; : > "$dir/$p"; fi
    done
    echo "$dir"
}

detect() {
    local ds
    ds="$(make_stub_dispatcher)"
    run "$BASH" "$ds/bootstrap.sh" --target "$1"
}

# ─── 1. 레거시 .claude-settings.json 제거 ─────────────────────────────────

@test "legacy: 언어 템플릿에 .claude-settings.json 이 없다" {
    for l in $LANGS; do
        [ ! -e "$REPO_ROOT/$l/templates/.claude-settings.json" ] || { echo "still exists: $l"; return 1; }
    done
}

@test "legacy: 어떤 bootstrap.sh 도 settings.local.json · .claude-settings.json 을 언급하지 않는다" {
    for l in $LANGS; do
        ! grep -n -E 'settings\.local\.json|\.claude-settings\.json' "$REPO_ROOT/$l/bootstrap.sh" \
            || { echo "still referenced: $l"; return 1; }
    done
}

@test "legacy: bootstrap 단계 번호가 1부터 빠짐없이 이어진다" {
    for l in $LANGS; do
        nums="$(grep -oE '^step "[0-9]+\.' "$REPO_ROOT/$l/bootstrap.sh" | grep -oE '[0-9]+' | tr '\n' ' ')"
        expected="$(seq 1 "$(echo "$nums" | wc -w)" | tr '\n' ' ')"
        [ "$nums" = "$expected" ] || { echo "$l: '$nums' != '$expected'"; return 1; }
    done
}

# ─── 3. LANG 로케일 보존 ──────────────────────────────────────────────────

@test "LANG: 루트 bootstrap 이 로케일 LANG 을 덮어쓰지 않는다 (--lang)" {
    ds="$(make_stub_dispatcher)"
    fx="$(make_fixture)"
    LANG=ko_KR.UTF-8 run "$BASH" "$ds/bootstrap.sh" --lang python --target "$fx"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RAN=python CHILD_LANG=ko_KR.UTF-8"* ]]
}

@test "LANG: 자동 감지 경로에서도 로케일 LANG 이 자식에 그대로 전달된다" {
    fx="$(make_fixture go.mod)"
    LANG=ko_KR.UTF-8 detect "$fx"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RAN=go CHILD_LANG=ko_KR.UTF-8"* ]]
}

# ─── 4. Gradle / Maven 감지 ──────────────────────────────────────────────

@test "detect: Groovy build.gradle(코틀린 없음) → java-spring" {
    fx="$(make_fixture src/main/java/)"
    printf "plugins {\n  id 'java'\n  id 'org.springframework.boot' version '3.3.0'\n}\n" > "$fx/build.gradle"
    detect "$fx"
    [[ "$output" == *"RAN=java-spring"* ]]
}

@test "detect: build.gradle 하나만 있어도 코틀린 흔적이 없으면 java-spring" {
    fx="$(make_fixture build.gradle settings.gradle)"
    detect "$fx"
    [[ "$output" == *"RAN=java-spring"* ]]
}

@test "detect: build.gradle.kts → kotlin-spring" {
    fx="$(make_fixture build.gradle.kts)"
    detect "$fx"
    [[ "$output" == *"RAN=kotlin-spring"* ]]
}

@test "detect: build.gradle + src/main/kotlin → kotlin-spring" {
    fx="$(make_fixture build.gradle src/main/kotlin/)"
    detect "$fx"
    [[ "$output" == *"RAN=kotlin-spring"* ]]
}

@test "detect: Groovy build.gradle 의 kotlin 플러그인 선언 → kotlin-spring" {
    fx="$(make_fixture)"
    printf "plugins {\n  id 'org.jetbrains.kotlin.jvm' version '2.0.0'\n}\n" > "$fx/build.gradle"
    detect "$fx"
    [[ "$output" == *"RAN=kotlin-spring"* ]]
}

@test "detect: pom.xml → java-spring, kotlin-maven-plugin 이 있으면 kotlin-spring" {
    fx="$(make_fixture pom.xml)"
    detect "$fx"
    [[ "$output" == *"RAN=java-spring"* ]]
    printf '<project><build><plugins><plugin><artifactId>kotlin-maven-plugin</artifactId></plugin></plugins></build></project>\n' > "$fx/pom.xml"
    detect "$fx"
    [[ "$output" == *"RAN=kotlin-spring"* ]]
}

@test "detect: settings.gradle 만 있고 빌드 파일·소스 흔적이 없으면 unknown" {
    for f in settings.gradle settings.gradle.kts; do
        fx="$(make_fixture "$f")"
        detect "$fx"
        [ "$status" -eq 1 ] || { echo "$f: status=$status"; return 1; }
        [[ "$output" == *"감지할 수 없습니다"* ]]
        [[ "$output" != *"RAN="* ]]
    done
}

# ─── 2. TypeScript husky ─────────────────────────────────────────────────

# 가짜 PATH: node 는 버전만, npx 는 $1 모드(fail|ok)로 동작. 실제 husky·npm 은 PATH 에 없다
ts_env() {
    local mode="$1" stub="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$stub"
    printf '#!/bin/sh\necho v20.0.0\n' > "$stub/node"
    if [[ "$mode" == "ok" ]]; then
        printf '#!/bin/sh\n[ "$1 $2" = "husky init" ] || exit 1\nmkdir -p .husky && echo "npm test" > .husky/pre-commit\n' > "$stub/npx"
    else
        printf '#!/bin/sh\nexit 1\n' > "$stub/npx"
    fi
    chmod +x "$stub/node" "$stub/npx"
    fx="$(make_fixture .git/)"
    echo '{}' > "$fx/package.json"
    printf 'y\nn\nn\n' > "$BATS_TEST_TMPDIR/answers"
    STUB="$stub"
}

run_ts() {
    run env PATH="$STUB:/usr/bin:/bin" "$BASH" "$REPO_ROOT/typescript-react/bootstrap.sh" --target "$fx" \
        < "$BATS_TEST_TMPDIR/answers"
}

@test "husky: husky 미설치로 init 이 실패하면 경고하고 건너뛴다 (스크립트가 죽지 않는다)" {
    ts_env fail
    run_ts
    [ "$status" -eq 0 ]
    [[ "$output" == *"husky"*"건너뜀"* ]]
    [ ! -e "$fx/.husky" ]
    [[ "$output" == *"품질 체계 적용 완료"* ]]
}

@test "husky: init 이 실패해도 로컬 husky 가 있으면 .husky 를 만들고 훅을 쓴다" {
    ts_env fail
    mkdir -p "$fx/node_modules/.bin"
    printf '#!/bin/sh\nexit 0\n' > "$fx/node_modules/.bin/husky"
    chmod +x "$fx/node_modules/.bin/husky"
    run_ts
    [ "$status" -eq 0 ]
    grep -q 'lint-staged' "$fx/.husky/pre-commit"
    grep -q '.githooks/pre-push' "$fx/.husky/pre-push"
}

@test "husky: init 성공 시 .husky/pre-push 가 .githooks/pre-push 를 실행한다 (있을 때만)" {
    ts_env ok
    run_ts
    [ "$status" -eq 0 ]
    [ -f "$fx/.husky/pre-push" ]

    # .githooks/pre-push 가 없으면 통과
    run sh -c 'cd "$1" && sh .husky/pre-push origin url < /dev/null' _ "$fx"
    [ "$status" -eq 0 ]

    # 있으면 그 결과(종료 코드·stdin)를 그대로 따른다
    mkdir -p "$fx/.githooks"
    printf '#!/bin/sh\ncat > "$(dirname "$0")/seen"\nexit 7\n' > "$fx/.githooks/pre-push"
    chmod +x "$fx/.githooks/pre-push"
    run sh -c 'cd "$1" && echo "refs/heads/x abc refs/heads/x def" | sh .husky/pre-push origin url' _ "$fx"
    [ "$status" -eq 7 ]
    grep -q 'refs/heads/x abc' "$fx/.githooks/seen"
}

# ─── 5. pre-commit 경유 pre-push 영수증 ──────────────────────────────────

@test "pre-push: .pre-commit-config.yaml 템플릿마다 test-receipt-pre-push 로컬 훅이 있다" {
    n=0
    for l in $LANGS; do
        cfg="$REPO_ROOT/$l/templates/.pre-commit-config.yaml"
        [ -f "$cfg" ] || continue
        n=$((n + 1))
        block="$(grep -A6 -E '^\s*- id: test-receipt-pre-push$' "$cfg")" || { echo "missing: $l"; return 1; }
        for want in 'entry: .githooks/pre-push' 'language: script' 'stages: \[pre-push\]' \
                    'always_run: true' 'pass_filenames: false'; do
            echo "$block" | grep -qE "^\s*$want\s*$" || { echo "$l: missing '$want'"; return 1; }
        done
    done
    [ "$n" -ge 9 ]
}

@test "pre-push: pre-commit install 을 부르는 bootstrap 은 pre-commit·pre-push 훅 타입을 한 번에 설치한다" {
    for l in $LANGS; do
        f="$REPO_ROOT/$l/bootstrap.sh"
        installs="$(grep -E '^[^#]*pre[-_]commit install' "$f" | grep -v -E '^\s*(warn|info|echo)')" || continue
        [ "$(echo "$installs" | wc -l)" -eq 1 ] || { echo "$l: multiple install lines"; echo "$installs"; return 1; }
        echo "$installs" | grep -q -- '--hook-type pre-commit --hook-type pre-push' \
            || { echo "$l: $installs"; return 1; }
    done
}

@test "pre-push: 언어 템플릿·bootstrap 에 core.hooksPath 안내가 없다" {
    for l in $LANGS; do
        ! grep -rn 'core.hooksPath' "$REPO_ROOT/$l/templates" "$REPO_ROOT/$l/bootstrap.sh" \
            || { echo "found in $l"; return 1; }
    done
}
