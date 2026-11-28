#!/usr/bin/env bats
# tests/template-configs.bats — 배포 템플릿의 설정을 "실제 도구"가 받아들이고 약속대로 검사하는지 실행으로 확인한다.
# 근거: 표준 최신성 조사 (값은 맞는데 도구가 키를 무시·거부하던 결함들)
# 도구가 없으면 로컬에서는 skip, CI(TEMPLATE_TOOLS_REQUIRED=1)에서는 실패 — CI 에서 조용히 건너뛰지 않게 한다.

load helpers

# 임시 git 저장소에 파일 하나를 커밋하고 gitleaks 가 잡은 파일 목록을 출력한다.
gitleaks_findings() {
    local name="$1" content="$2" dir
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "bats"
    printf '%s\n' "$content" > "$dir/$name"
    git -C "$dir" add "$name"
    git -C "$dir" commit -q -m "add $name"
    gitleaks git --config "$REPO_ROOT/common/security-templates/gitleaks.toml" \
        --no-banner --exit-code 0 -r "$dir/report.json" "$dir" >/dev/null 2>&1
    jq -r '.[].File' "$dir/report.json" | sort -u
}

random_alnum() {
    head -c 400 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c "$1"
}

@test "gitleaks: 문서(.md) 안의 실제 토큰도 검출한다 — 허용목록이 .md 전체를 빼지 않는다" {
    require_tool gitleaks
    run gitleaks_findings notes.md "token = \"ghp_$(random_alnum 36)\""
    [ "$status" -eq 0 ]
    [ "$output" = "notes.md" ] || { echo "findings: [$output]"; return 1; }
}

@test "gitleaks: 문서 안의 자리표시자는 허용하고, 같은 자리표시자가 코드에 있으면 검출한다" {
    require_tool gitleaks
    # built at runtime: a literal here would be flagged by gitleaks on this very file
    local line
    line="$(printf '%s_%s = "%s_%s_%s"' api key example key 0123456789abcdef)"
    run gitleaks_findings guide.md "$line"
    [ "$output" = "" ] || { echo "md placeholder flagged: [$output]"; return 1; }
    run gitleaks_findings app.py "$line"
    [ "$output" = "app.py" ] || { echo "code placeholder not flagged: [$output]"; return 1; }
}

@test "golangci-lint: go 템플릿 설정이 v2 스키마 검증을 통과한다" {
    require_tool golangci-lint
    run golangci-lint config verify -c "$REPO_ROOT/go/templates/.golangci.yml"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "golangci-lint: v1 기본 예외(defer Close · 주석 없는 export · 생성 코드)가 v2 에서도 유지된다" {
    require_tool golangci-lint
    require_tool go
    local dir="$BATS_TEST_TMPDIR/go-defaults"
    mkdir -p "$dir"
    cp "$REPO_ROOT/go/templates/.golangci.yml" "$dir/.golangci.yml"
    cp "$PROJECT_ROOT/tests/fixtures/go-defaults/"*.go "$dir/"
    printf 'module example.com/fixture\n\ngo 1.24\n' > "$dir/go.mod"
    run bash -c "cd '$dir' && GOLANGCI_LINT_CACHE='$dir/.cache/lint' GOCACHE='$dir/.cache/go' golangci-lint run --enable-only errcheck,revive ./... 2>&1"
    echo "$output" | grep -q '^0 issues' || { echo "$output"; return 1; }
}

@test "golangci-lint: CI 템플릿은 v2 전용 액션(v7+)과 고정 버전을, pre-commit 은 v2 플래그를 쓴다" {
    local ci="$REPO_ROOT/common/ci-templates/ci-go.yml" pc="$REPO_ROOT/go/templates/.pre-commit-config.yaml"
    local major
    major="$(sed -nE 's|.*golangci/golangci-lint-action@[0-9a-f]{40} # v([0-9]+)\..*|\1|p' "$ci")"
    [ -n "$major" ] && [ "$major" -ge 7 ] || { echo "golangci-lint-action major: [$major]"; return 1; }
    run yq -r '.. | select(has("uses")) | select(.uses | test("golangci-lint-action")) | .with.version' "$ci"
    [ "$output" = '${{ env.GOLANGCI_LINT_VERSION }}' ] || { echo "action version not taken from GOLANGCI_LINT_VERSION: [$output]"; return 1; }
    run yq -r '.["env"].GOLANGCI_LINT_VERSION' "$ci"
    [[ "$output" =~ ^v2\.[0-9]+\.[0-9]+$ ]] || { echo "version not pinned to v2.x.y: [$output]"; return 1; }
    local ci_ver="$output"
    run yq -r '.repos[] | select(.repo | test("golangci/golangci-lint")) | .hooks[].args[]?' "$pc"
    if printf '%s\n' "$output" | grep -qx -- '--fast'; then echo "v1 flag --fast"; return 1; fi
    local revs repo_ci
    revs="$(yq -r '.repos[] | select(.repo | test("golangci/golangci-lint")) | .rev' "$pc" | sort -u)"
    repo_ci="v$(yq -r '.["env"].GOLANGCI_LINT_VERSION' "$PROJECT_ROOT/.github/workflows/ci.yml")"
    [ "$revs" = "$ci_ver" ] && [ "$repo_ci" = "$ci_ver" ] || { echo "versions differ: ci-template=$ci_ver pre-commit=[$revs] repo-ci=$repo_ci"; return 1; }
}

@test "cargo-deny: rust 템플릿 deny.toml 을 오류 없이 읽고 MIT 는 통과, copyleft(GPL) 는 거부한다" {
    require_tool cargo
    require_tool cargo-deny
    local dir="$BATS_TEST_TMPDIR/crate" lic
    mkdir -p "$dir/src"
    printf 'fn main() {}\n' > "$dir/src/main.rs"
    for lic in MIT GPL-3.0-only; do
        printf '[package]\nname = "fixture"\nversion = "0.1.0"\nedition = "2021"\nlicense = "%s"\npublish = false\n' "$lic" > "$dir/Cargo.toml"
        (cd "$dir" && cargo generate-lockfile --offline -q)
        run bash -c "cd '$dir' && cargo-deny --offline --config '$REPO_ROOT/rust/templates/deny.toml' check licenses bans sources 2>&1"
        if [ "$lic" = MIT ]; then
            [ "$status" -eq 0 ] || { echo "MIT rejected: $output"; return 1; }
        else
            [ "$status" -ne 0 ] || { echo "copyleft $lic accepted"; return 1; }
        fi
    done
}

@test "rust: clippy msrv 가 rustfmt edition 의 최소 Rust 버전 이상이다 (edition 2024 → 1.85)" {
    local edition msrv
    edition="$(sed -nE 's/^edition = "([0-9]+)"/\1/p' "$REPO_ROOT/rust/templates/rustfmt.toml")"
    msrv="$(sed -nE 's/^msrv = "([0-9.]+)"/\1/p' "$REPO_ROOT/rust/templates/clippy.toml")"
    [ -n "$edition" ] && [ -n "$msrv" ]
    if [ "$edition" = "2024" ]; then
        printf '1.85.0\n%s\n' "$msrv" | sort -V -C || { echo "msrv $msrv < 1.85.0 for edition 2024"; return 1; }
    fi
}

@test "gemini: 설정 템플릿이 현행 키 context.fileName 으로 AGENTS.md 를 읽게 한다" {
    local f="$REPO_ROOT/common/templates/GEMINI_SETTINGS_TEMPLATE.json"
    run jq -e '.context.fileName | index("AGENTS.md")' "$f"
    [ "$status" -eq 0 ] || { echo "context.fileName missing AGENTS.md"; return 1; }
    run jq -e 'has("contextFileName")' "$f"
    [ "$status" -ne 0 ] || { echo "legacy flat key contextFileName still present"; return 1; }
}

@test "ruby: .rubocop.yml 이 불러오는 gem 은 모두 bootstrap·README 설치 안내에 있다" {
    local cfg="$REPO_ROOT/ruby-rails/templates/.rubocop.yml" gem missing=""
    while IFS= read -r gem; do
        [ -n "$gem" ] || continue
        grep -q "gem \"$gem\"" "$REPO_ROOT/ruby-rails/bootstrap.sh" || missing="$missing bootstrap:$gem"
        grep -q "gem \"$gem\"" "$REPO_ROOT/ruby-rails/README.md" || missing="$missing README:$gem"
    done < <(yq -r '(.inherit_gem // {} | keys | .[]), (.require // [] | .[]), (.plugins // [] | .[])' "$cfg")
    [ -z "$missing" ] || { echo "missing:$missing"; return 1; }
}
