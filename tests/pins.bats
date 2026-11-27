#!/usr/bin/env bats
# tests/pins.bats — 버전 핀이 Renovate 가 읽을 수 있는 한 가지 형식으로만 있다 (로드맵 2단계 A20 · H-E3).
#
# 규약: 도구 버전은 `*_VERSION` 변수 한 곳에만, 큰따옴표 값으로 두고, 바로 윗줄에 주석을 단다.
#   # renovate: datasource=<id> depName=<name> [versioning=<v>] [extractVersion=<re>]
#   FOO_VERSION: "1.2.3"        (YAML)      FOO_VERSION="1.2.3"   (shell)
# 스크립트 본문은 ${FOO_VERSION} 으로 참조한다. `latest` 는 어디에도 쓰지 않는다.
# Renovate 기본 매니저가 읽는 것(uses: SHA · container image: · .pre-commit-config.yaml rev · package.json ·
# libs.versions.toml · devcontainer image)은 이 규약 밖이다.
# 파일 단위 핀: typescript-react/templates/dev-dependencies.txt 는 줄마다 name@x.y.z 이고, 파일 전체를 하나의
# customManager 가 읽는다(2b renovate.json) — 줄마다 주석을 달지 않는다.

load helpers

PIN_FILES=(
    .github/workflows/ci.yml
    .github/workflows/security-review.yml
    .github/workflows/pr-checks.yml
    .github/workflows/ai-ready-guard.yml
    .github/workflows/template-freshness.yml
    .github/workflows/renovate.yml
    scripts/install-dev-tools.sh
    plugins/sos/standards/common/testing-templates/coverage-gate.sh
)
FILE_LEVEL_PINS=(plugins/sos/standards/typescript-react/templates/dev-dependencies.txt)

DATASOURCES="golang-version node-version python-version java-version ruby-version github-releases github-tags pypi npm go docker"

pin_files() {
    local f
    for f in "${PIN_FILES[@]}"; do echo "$f"; done
    (cd "$PROJECT_ROOT" && ls plugins/sos/standards/common/ci-templates/*.yml plugins/sos/standards/common/security-templates/*.yml plugins/sos/standards/common/github-templates/workflows/*.yml)
}

# Every *_VERSION declaration (any value format) — a declaration the convention cannot read is a failure,
# not something to skip. Prints "file:line: reason: text".
version_violations() { # file [label]
    awk -v f="${2:-$1}" '
        /^[[:space:]]*#/ { prev = $0; next }
        /^[[:space:]]*(export[[:space:]]+)?[A-Z0-9_]+_VERSION[[:space:]]*(:|=)/ {
            if ($0 !~ /^[[:space:]]*(export[[:space:]]+)?[A-Z0-9_]+_VERSION(: |=)"v?[0-9][^"]*"([[:space:]]+#.*)?[[:space:]]*$/)
                printf "%s:%d: unsupported format (use NAME_VERSION: \"x.y.z\"): %s\n", f, NR, $0
            else if (prev !~ /^[[:space:]]*# renovate: datasource=[a-z-]+ depName=[^ ]+/)
                printf "%s:%d: no # renovate: annotation above: %s\n", f, NR, $0
        }
        { prev = $0 }' "$1"
}

# Versions written straight into a body. uses: (SHA) and image: keys are native-manager pins; *_VERSION lines
# are checked above. Prints "file:line: text".
inline_violations() { # file [label]
    awk -v f="${2:-$1}" '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*(-[[:space:]]+)?uses:/ { next }
        /^[[:space:]]*image:/ { next }
        /^[[:space:]]*(export[[:space:]]+)?[A-Z0-9_]+_VERSION[[:space:]]*(:|=)/ { next }
        /[a-z0-9]==[0-9]+\.[0-9]/ ||
        /[a-z0-9-]@v?[0-9]+\.[0-9]+/ ||
        /@latest/ ||
        /releases\/download\/v?[0-9]+\.[0-9]/ ||
        /version:[[:space:]]*["\047]?(v?[0-9]+\.[0-9]|latest)/ ||
        /\|\|[[:space:]]*["\047]v?[0-9]+\.[0-9]/ ||
        /[a-z0-9.\/_-]+:[0-9][^ "\047]*@sha256:/ { printf "%s:%d: %s\n", f, NR, $0 }' "$1"
}

@test "pins: 범위 안의 모든 *_VERSION 선언이 큰따옴표 값이고 바로 윗줄에 # renovate: 주석이 있다" {
    local f out bad="" n=0
    while IFS= read -r f; do
        out="$(version_violations "$PROJECT_ROOT/$f" "$f")" || { echo "scan failed on $f"; return 1; }
        bad="$bad$out"
        n=$(( n + $(grep -cE '^[[:space:]]*(export[[:space:]]+)?[A-Z0-9_]+_VERSION[[:space:]]*(:|=)' "$PROJECT_ROOT/$f" || true) ))
    done < <(pin_files)
    [ "$n" -ge 1 ] || { echo "no *_VERSION declarations found — the scan is broken"; return 1; }
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

@test "pins: 스크립트 본문에 버전을 직접 박은 핀·latest 가 없다" {
    local f out bad=""
    while IFS= read -r f; do
        out="$(inline_violations "$PROJECT_ROOT/$f" "$f")" || { echo "scan failed on $f"; return 1; }
        bad="$bad$out"
    done < <(pin_files)
    [ -z "$bad" ] || { echo "inline version pins (move to an annotated *_VERSION variable):"; echo "$bad"; return 1; }
}

@test "pins: 반증 — 리뷰가 찾은 우회 표기가 모두 검출된다" {
    local fx="$BATS_TEST_TMPDIR/bypass.yml" out line n
    cat > "$fx" <<'EOF'
env:
  GO_VERSION: '1.26'
  NODE_VERSION: "24"
  # renovate: datasource=npm depName=x
  X_VERSION: 1.2.3
jobs:
  a:
    steps:
      - uses: some/action@0123456789012345678901234567890123456789 # v1
        with:
          version: "v2.15.0"
          other: ${{ inputs.lint_version || 'v2.15.0' }}
          pnpm: latest
      - run: |
          docker run "semgrep/semgrep:1.177.0@sha256:acaac22ffc7b7cc5926de0751b223bce0b2491c33d18422fa72f632c78d81198"
          go install golang.org/x/vuln/cmd/govulncheck@latest
          pip install ruff==0.15.4
          npm i -g markdownlint-cli2@0.23.2
          version: latest
EOF
    out="$(version_violations "$fx"; inline_violations "$fx")"
    n=0
    for line in 2 3 5 11 12 15 16 17 18 19; do
        grep -q ":$line: " <<< "$out" || { echo "line $line not detected"; return 1; }
        n=$(( n + 1 ))
    done
    if grep -q ':9: ' <<< "$out"; then echo "uses: SHA pin flagged (native manager)"; return 1; fi
    [ "$n" -eq 10 ]
}

@test "pins: # renovate: 주석의 datasource 가 Renovate 가 아는 값이다" {
    local f ds bad="" n=0
    while IFS= read -r f; do
        while IFS= read -r ds; do
            n=$(( n + 1 ))
            [[ " $DATASOURCES " == *" $ds "* ]] || bad="$bad $f:$ds"
        done < <(sed -nE 's/^[[:space:]]*# renovate: datasource=([a-z-]+) .*/\1/p' "$PROJECT_ROOT/$f")
    done < <(pin_files)
    [ "$n" -ge 1 ] || { echo "no annotations found"; return 1; }
    [ -z "$bad" ] || { echo "unknown datasource:$bad"; return 1; }
}

@test "pins: 파일 단위 핀 파일은 주석·빈 줄 말고는 모두 name@x.y.z 다" {
    local f bad=""
    for f in "${FILE_LEVEL_PINS[@]}"; do
        [ -f "$PROJECT_ROOT/$f" ] || { echo "missing $f"; return 1; }
        bad="$bad$(grep -nvE '^(#|$)|^(@[a-z0-9-]+/)?[a-z0-9.-]+@[0-9]+\.[0-9]+\.[0-9]+( [a-z-]+)?$' "$PROJECT_ROOT/$f" | sed "s|^|$f:|" || true)"
    done
    [ -z "$bad" ] || { echo "not an exact name@x.y.z pin: $bad"; return 1; }
}
