#!/usr/bin/env bash
# ============================================================================
# scripts/install-dev-tools.sh — 검증 도구 일괄 설치 (OS 독립)
# ============================================================================
# ShipOrSink 저장소를 검증(shellcheck · bats · actionlint · markdownlint)
# 하거나 GitHub 설정 스크립트(gh · jq)와 보안 훅(gitleaks · pre-commit)을
# 쓰려면 아래 8종이 필요하다. 이 스크립트는 OS와 패키지 관리자를 감지해
# 한 번에 설치한다. 이미 설치된 도구는 건너뛴다(멱등).
#
# 사용법:
#   bash scripts/install-dev-tools.sh            # 감지 → 확인 → 설치
#   bash scripts/install-dev-tools.sh --check    # 설치 없이 현황만 출력
#   bash scripts/install-dev-tools.sh --yes      # 확인 없이 설치 (CI/무인)
#   bash scripts/install-dev-tools.sh --pm apt   # 패키지 관리자 강제 (brew|apt|dnf|pacman|scoop|none)
#
# 우선순위:
#   macOS / Linux : brew > apt > dnf > pacman
#   Windows       : scoop (Git Bash · MSYS2 · WSL 은 Linux 로 처리)
#   네이티브 관리자에 패키지가 없으면 크로스 OS 폴백 →
#     npm -g (버전 고정) · pipx · go install · GitHub 릴리스 바이너리(체크섬 검증)
#   `curl | sh` 는 쓰지 않는다 — 바이너리는 받은 뒤 sha256 을 대조하고 설치한다.
# ============================================================================
set -euo pipefail

TOOLS="gh jq shellcheck bats actionlint markdownlint-cli2 gitleaks pre-commit"

# 폴백 전용 핀 버전 — 네이티브 패키지 관리자는 자체 버전을 쓴다.
# 갱신은 Renovate 가 `# renovate:` 주석으로 한다(로드맵 2단계 · tests/pins.bats).
# renovate: datasource=github-releases depName=rhysd/actionlint extractVersion=^v(?<version>.*)$
ACTIONLINT_VERSION="1.7.12"
# renovate: datasource=github-releases depName=gitleaks/gitleaks extractVersion=^v(?<version>.*)$
GITLEAKS_VERSION="8.30.1"
# renovate: datasource=npm depName=markdownlint-cli2
MARKDOWNLINT_CLI2_VERSION="0.23.2"
# renovate: datasource=npm depName=bats
BATS_NPM_VERSION="1.13.0"
# renovate: datasource=pypi depName=pre-commit
PRE_COMMIT_VERSION="4.6.2"

CHECK_ONLY=false
ASSUME_YES=false
PM_OVERRIDE=""
LOCAL_BIN="${HOME}/.local/bin"

# ─── Colors & helpers (apply.sh 와 동일) ────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}\n"; }

# ─── 인자 파싱 ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)   CHECK_ONLY=true; shift ;;
        --yes|-y)  ASSUME_YES=true; shift ;;
        --pm)      PM_OVERRIDE="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) error "알 수 없는 옵션: $1"; exit 1 ;;
    esac
done

# ─── OS · 아키텍처 · 패키지 관리자 감지 ─────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Darwin)                 echo "macos" ;;
        Linux)                  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*)   echo "windows" ;;
        *)                      echo "unknown" ;;
    esac
}

# 릴리스 자산 이름에 쓰는 아키텍처 표기. 도구마다 표기가 달라 두 가지를 돌려준다.
#   go 계열(actionlint): amd64 / arm64      gitleaks: x64 / arm64
detect_arch_go()       { case "$(uname -m)" in x86_64|amd64) echo "amd64" ;; aarch64|arm64) echo "arm64" ;; *) echo "" ;; esac; }
detect_arch_gitleaks() { case "$(uname -m)" in x86_64|amd64) echo "x64"   ;; aarch64|arm64) echo "arm64" ;; *) echo "" ;; esac; }

detect_pm() {
    local os="$1"
    case "$os" in
        macos|linux)
            if   command -v brew   >/dev/null 2>&1; then echo "brew"
            elif command -v apt-get >/dev/null 2>&1; then echo "apt"
            elif command -v dnf    >/dev/null 2>&1; then echo "dnf"
            elif command -v pacman >/dev/null 2>&1; then echo "pacman"
            else echo "none"; fi ;;
        windows)
            if command -v scoop >/dev/null 2>&1; then echo "scoop"; else echo "none"; fi ;;
        *) echo "none" ;;
    esac
}

# 패키지 관리자별 패키지 이름. 없으면 빈 문자열 → 폴백으로 넘어간다.
pkg_name() {
    local tool="$1" pm="$2"
    case "$pm" in
        brew)
            case "$tool" in
                bats) echo "bats-core" ;;
                *)    echo "$tool" ;;
            esac ;;
        apt)
            case "$tool" in
                gh|jq|shellcheck|bats|pre-commit) echo "$tool" ;;
                *) echo "" ;;
            esac ;;
        dnf)
            case "$tool" in
                shellcheck) echo "ShellCheck" ;;
                gh|jq|bats|pre-commit) echo "$tool" ;;
                *) echo "" ;;
            esac ;;
        pacman)
            case "$tool" in
                gh) echo "github-cli" ;;
                jq|shellcheck|bats|actionlint|gitleaks|pre-commit) echo "$tool" ;;
                *) echo "" ;;
            esac ;;
        scoop)
            case "$tool" in
                gh|jq|shellcheck|actionlint|gitleaks) echo "$tool" ;;
                *) echo "" ;;
            esac ;;
        *) echo "" ;;
    esac
}

# 루트가 아니면 sudo 를 붙인다 (apt · dnf · pacman 전용).
as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

install_native() {
    local tool="$1" pm="$2"
    local pkg
    pkg="$(pkg_name "$tool" "$pm")"
    [[ -z "$pkg" ]] && return 1

    info "$tool ← $pm ($pkg)"
    case "$pm" in
        brew)   brew install "$pkg" ;;
        apt)
            # 오래된 Ubuntu 에는 gh 패키지가 없다 — 후보가 없으면 폴백으로
            apt-cache show "$pkg" >/dev/null 2>&1 || return 1
            # 러너처럼 인덱스가 오래된 환경에서 404 를 피한다 (한 번만)
            if [[ "${APT_UPDATED:-}" != true ]]; then as_root apt-get update -qq || true; APT_UPDATED=true; fi
            as_root apt-get install -y "$pkg" ;;
        dnf)    as_root dnf install -y "$pkg" ;;
        pacman) as_root pacman -S --noconfirm --needed "$pkg" ;;
        scoop)  scoop install "$pkg" ;;
        *)      return 1 ;;
    esac
}

# ─── 크로스 OS 폴백 ─────────────────────────────────────────────────────
sha256_of() {
    if   command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum    >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else return 1; fi
}

# GitHub 릴리스 바이너리 설치: 자산 + 체크섬 파일을 받아 sha256 대조 후 ~/.local/bin 에 둔다.
#   $1 도구명  $2 자산 URL  $3 체크섬 URL  $4 자산 파일명  $5 압축 안의 실행 파일명
install_binary_release() {
    local tool="$1" asset_url="$2" sums_url="$3" asset="$4" bin="$5"
    local tmp expected actual
    command -v curl >/dev/null 2>&1 || { warn "curl 이 없어 $tool 바이너리를 받을 수 없습니다"; return 1; }

    tmp="$(mktemp -d)"
    info "$tool ← GitHub 릴리스 ($asset)"
    curl -fsSL -o "$tmp/$asset" "$asset_url"        || { rm -rf "$tmp"; return 1; }
    curl -fsSL -o "$tmp/checksums.txt" "$sums_url"  || { rm -rf "$tmp"; return 1; }

    expected="$(grep " $asset\$" "$tmp/checksums.txt" | awk '{print $1}' || true)"
    actual="$(sha256_of "$tmp/$asset")"
    if [[ -z "$expected" || "$expected" != "$actual" ]]; then
        error "$tool 체크섬 불일치 — 설치 중단 (expected=$expected actual=$actual)"
        rm -rf "$tmp"; return 1
    fi

    mkdir -p "$LOCAL_BIN"
    case "$asset" in
        *.tar.gz) tar -xzf "$tmp/$asset" -C "$tmp" "$bin" ;;
        *.zip)    command -v unzip >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }
                  unzip -oq "$tmp/$asset" "$bin" -d "$tmp" ;;
    esac
    install -m 0755 "$tmp/$bin" "$LOCAL_BIN/$bin"
    rm -rf "$tmp"
}

install_actionlint_fallback() {
    local os="$1" arch asset ext="tar.gz" bin="actionlint"
    arch="$(detect_arch_go)"; [[ -z "$arch" ]] && return 1
    [[ "$os" == "windows" ]] && { ext="zip"; bin="actionlint.exe"; }
    if command -v go >/dev/null 2>&1; then
        info "actionlint ← go install (v${ACTIONLINT_VERSION})"
        go install "github.com/rhysd/actionlint/cmd/actionlint@v${ACTIONLINT_VERSION}" && return 0
    fi
    asset="actionlint_${ACTIONLINT_VERSION}_${os/macos/darwin}_${arch}.${ext}"
    install_binary_release "actionlint" \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${asset}" \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_checksums.txt" \
        "$asset" "$bin"
}

install_gitleaks_fallback() {
    local os="$1" arch asset ext="tar.gz" bin="gitleaks"
    arch="$(detect_arch_gitleaks)"; [[ -z "$arch" ]] && return 1
    [[ "$os" == "windows" ]] && { ext="zip"; bin="gitleaks.exe"; }
    asset="gitleaks_${GITLEAKS_VERSION}_${os/macos/darwin}_${arch}.${ext}"
    install_binary_release "gitleaks" \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${asset}" \
        "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
        "$asset" "$bin"
}

install_fallback() {
    local tool="$1" os="$2"
    case "$tool" in
        markdownlint-cli2)
            command -v npm >/dev/null 2>&1 || return 1
            info "markdownlint-cli2 ← npm -g (${MARKDOWNLINT_CLI2_VERSION})"
            npm install -g "markdownlint-cli2@${MARKDOWNLINT_CLI2_VERSION}" ;;
        bats)
            command -v npm >/dev/null 2>&1 || return 1
            info "bats ← npm -g (${BATS_NPM_VERSION})"
            npm install -g "bats@${BATS_NPM_VERSION}" ;;
        pre-commit)
            if command -v pipx >/dev/null 2>&1; then
                info "pre-commit ← pipx (${PRE_COMMIT_VERSION})"
                pipx install "pre-commit==${PRE_COMMIT_VERSION}"
            elif command -v python3 >/dev/null 2>&1; then
                info "pre-commit ← pip --user (${PRE_COMMIT_VERSION})"
                python3 -m pip install --user "pre-commit==${PRE_COMMIT_VERSION}"
            else return 1; fi ;;
        actionlint) install_actionlint_fallback "$os" ;;
        gitleaks)   install_gitleaks_fallback "$os" ;;
        *) return 1 ;;   # gh · jq · shellcheck 는 폴백 없음 → 수동 안내
    esac
}

manual_hint() {
    case "$1" in
        gh)         echo "https://github.com/cli/cli#installation" ;;
        jq)         echo "https://jqlang.github.io/jq/download/" ;;
        shellcheck) echo "https://github.com/koalaman/shellcheck#installing" ;;
        bats)       echo "https://bats-core.readthedocs.io/en/stable/installation.html" ;;
        actionlint) echo "https://github.com/rhysd/actionlint/blob/main/docs/install.md" ;;
        markdownlint-cli2) echo "https://github.com/DavidAnson/markdownlint-cli2#install" ;;
        gitleaks)   echo "https://github.com/gitleaks/gitleaks#installing" ;;
        pre-commit) echo "https://pre-commit.com/#install" ;;
    esac
}

# ─── 현황 · 실행 ────────────────────────────────────────────────────────
print_status() {
    local tool state
    printf "  %-20s %s\n" "도구" "상태"
    printf "  %-20s %s\n" "--------------------" "----------"
    for tool in $TOOLS; do
        if command -v "$tool" >/dev/null 2>&1; then state="${GREEN}설치됨${NC}  $(command -v "$tool")"
        else state="${RED}없음${NC}"; fi
        printf "  %-20s " "$tool"; echo -e "$state"
    done
}

OS="$(detect_os)"
PM="${PM_OVERRIDE:-$(detect_pm "$OS")}"
case "$PM" in brew|apt|dnf|pacman|scoop|none) ;; *) error "알 수 없는 --pm 값: $PM"; exit 1 ;; esac

header "ShipOrSink 검증 도구"
info "OS: $OS · 패키지 관리자: $PM · 폴백 설치 경로: $LOCAL_BIN"
echo ""
print_status
echo ""

MISSING=""
for tool in $TOOLS; do
    command -v "$tool" >/dev/null 2>&1 || MISSING="$MISSING $tool"
done

if [[ -z "$MISSING" ]]; then
    success "8종 모두 설치되어 있습니다"
    exit 0
fi

if [[ "$CHECK_ONLY" == true ]]; then
    warn "누락:${MISSING}"
    exit 1
fi

if [[ "$OS" == "unknown" || "$PM" == "none" ]]; then
    warn "패키지 관리자를 찾지 못했습니다 — 폴백(npm · pipx · go · 릴리스 바이너리)만 시도합니다"
fi

if [[ "$ASSUME_YES" != true ]]; then
    echo -n "누락된 도구(${MISSING} )를 설치할까요? (Y/n): "
    read -r confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then info "취소되었습니다."; exit 0; fi
fi

FAILED=""
for tool in $MISSING; do
    if install_native "$tool" "$PM" 2>/dev/null || install_fallback "$tool" "$OS"; then
        success "$tool 설치 완료"
    else
        FAILED="$FAILED $tool"
        warn "$tool 자동 설치 불가 — 수동: $(manual_hint "$tool")"
    fi
done

echo ""
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]] && [[ -d "$LOCAL_BIN" ]]; then
    warn "$LOCAL_BIN 이 PATH 에 없습니다 — 셸 설정에 추가하세요: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

if [[ -n "$FAILED" ]]; then
    error "설치 실패:${FAILED}"
    exit 1
fi
success "설치 완료 — 확인: bash scripts/install-dev-tools.sh --check"
