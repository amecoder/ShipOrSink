#!/usr/bin/env bash
# swift/bootstrap.sh — Swift 프로젝트에 품질 체계 적용
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PWD}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

TPL_DIR="$SCRIPT_DIR/templates"
cd "$TARGET_DIR"

# ── Helpers ────────────────────────────────────────────────────────────────
ask()     { read -r -p "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "── $* ──────────────────────────────────────"; }

# ── 1. Swift 환경 확인 ───────────────────────────────────────────────────
step "1. Swift 환경 확인"

if ! command -v swift &>/dev/null; then
    warn "Swift가 설치되어 있지 않습니다."
    warn "Xcode 또는 Swift 툴체인을 설치 후 다시 실행하세요."
    exit 1
fi

SWIFT_VERSION=$(swift --version 2>&1 | head -1)
success "$SWIFT_VERSION"

# Check for Xcode (macOS)
if command -v xcodebuild &>/dev/null; then
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
    success "$XCODE_VERSION"
fi

# ── 2. SwiftLint 설치 확인 ───────────────────────────────────────────────
step "2. SwiftLint 설치 확인"

if command -v swiftlint &>/dev/null; then
    SWIFTLINT_VERSION=$(swiftlint version 2>/dev/null)
    success "SwiftLint $SWIFTLINT_VERSION 발견"
else
    warn "SwiftLint가 설치되어 있지 않습니다."
    echo ""
    echo "  설치 방법:"
    echo "    brew install swiftlint          # Homebrew (macOS)"
    echo "    mint install realm/SwiftLint     # Mint"
    echo ""
    if command -v brew &>/dev/null; then
        if ask "  Homebrew로 SwiftLint를 설치할까요?"; then
            brew install swiftlint
            success "SwiftLint 설치 완료"
        fi
    else
        warn "설치 후 다시 실행하세요."
    fi
fi

# ── 3. SwiftFormat 설치 확인 ──────────────────────────────────────────────
step "3. SwiftFormat 설치 확인"

if command -v swiftformat &>/dev/null; then
    SWIFTFORMAT_VERSION=$(swiftformat --version 2>/dev/null)
    success "SwiftFormat $SWIFTFORMAT_VERSION 발견"
else
    warn "SwiftFormat이 설치되어 있지 않습니다."
    echo ""
    echo "  설치 방법:"
    echo "    brew install swiftformat         # Homebrew (macOS)"
    echo "    mint install nicklockwood/SwiftFormat  # Mint"
    echo ""
    if command -v brew &>/dev/null; then
        if ask "  Homebrew로 SwiftFormat을 설치할까요?"; then
            brew install swiftformat
            success "SwiftFormat 설치 완료"
        fi
    else
        warn "설치 후 다시 실행하세요."
    fi
fi

# ── 4. Periphery 설치 확인 (데드코드) ────────────────────────────────────
step "4. Periphery 설치 확인 (데드코드 탐지)"

if command -v periphery &>/dev/null; then
    PERIPHERY_VERSION=$(periphery version 2>/dev/null)
    success "Periphery $PERIPHERY_VERSION 발견"
else
    warn "Periphery가 설치되어 있지 않습니다."
    echo ""
    echo "  설치 방법:"
    echo "    brew install peripheryapp/periphery/periphery  # Homebrew"
    echo ""
    if command -v brew &>/dev/null; then
        if ask "  Homebrew로 Periphery를 설치할까요?"; then
            brew install peripheryapp/periphery/periphery
            success "Periphery 설치 완료"
        fi
    else
        info "건너뜀. Periphery는 선택 사항입니다."
    fi
fi

# ── 5. .swiftlint.yml ────────────────────────────────────────────────────
step "5. .swiftlint.yml — SwiftLint 설정"

if [[ -f ".swiftlint.yml" ]]; then
    warn ".swiftlint.yml이 이미 존재합니다."
    if ask "  strict 설정으로 덮어쓸까요?"; then
        cp "$TPL_DIR/.swiftlint.yml" .swiftlint.yml
        success ".swiftlint.yml 업데이트 완료"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/.swiftlint.yml" .swiftlint.yml
    success ".swiftlint.yml 생성 완료"
fi

# Adjust included paths
if [[ -d "Sources" ]]; then
    info "Sources/ 디렉터리 감지됨. .swiftlint.yml의 included 경로를 확인하세요."
elif [[ -d "src" ]]; then
    warn "src/ 디렉터리 감지됨. .swiftlint.yml의 included를 'src'로 수정하세요."
fi

# ── 6. .swiftformat ──────────────────────────────────────────────────────
step "6. .swiftformat — SwiftFormat 설정"

if [[ -f ".swiftformat" ]]; then
    warn ".swiftformat이 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.swiftformat" .swiftformat
        success ".swiftformat 업데이트 완료"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/.swiftformat" .swiftformat
    success ".swiftformat 생성 완료"
fi

# Detect Swift version for --swiftversion
if command -v swift &>/dev/null; then
    SWIFT_VER=$(swift --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if [[ -n "$SWIFT_VER" ]]; then
        sed -i.bak "s/--swiftversion 5.9/--swiftversion $SWIFT_VER/" .swiftformat \
            && rm -f .swiftformat.bak
        success "Swift 버전을 $SWIFT_VER 으로 자동 설정"
    fi
fi

# ─── coverage gate ──────────────────────────────────────────────────────────
# scripts/coverage-gate.sh — pre-push 훅 coverage-gate 가 부른다(바뀐 줄 80% + 전체가 .coverage-baseline 아래로 떨어지지 않음)
if [[ -f "scripts/coverage-gate.sh" ]]; then
    warn "scripts/coverage-gate.sh 이미 존재합니다. 건너뜀."
else
    mkdir -p scripts
    cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh
    chmod +x scripts/coverage-gate.sh
    success "scripts/coverage-gate.sh 생성 완료 (uv 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
fi

# ── 7. pre-commit 설정 ───────────────────────────────────────────────────
step "7. .pre-commit-config.yaml"

if [[ -f ".pre-commit-config.yaml" ]]; then
    warn ".pre-commit-config.yaml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
        success ".pre-commit-config.yaml 업데이트 완료"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
    success ".pre-commit-config.yaml 생성 완료"
fi

# Install pre-commit if available
if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
    PIP_CMD="pip3"
    command -v pip3 &>/dev/null || PIP_CMD="pip"

    if ! command -v pre-commit &>/dev/null; then
        if ask "  pre-commit + detect-secrets를 설치할까요?"; then
            $PIP_CMD install --quiet pre-commit detect-secrets
            success "pre-commit + detect-secrets 설치 완료"
        fi
    else
        success "pre-commit 이미 설치됨"
    fi
fi

# ── 8. detect-secrets baseline ────────────────────────────────────────────
step "8. detect-secrets baseline 생성"

if [[ -f ".secrets.baseline" ]]; then
    warn ".secrets.baseline 이미 존재합니다. 건너뜀."
else
    if command -v detect-secrets &>/dev/null; then
        detect-secrets scan \
            --exclude-files 'Pods/.*' \
            --exclude-files 'Carthage/.*' \
            --exclude-files '\.build/.*' \
            --exclude-files 'Build/.*' \
            --exclude-files 'DerivedData/.*' \
            > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    else
        warn "detect-secrets가 설치되어 있지 않습니다. 'pip install detect-secrets' 후 수동 생성하세요."
    fi
fi

# ── 9. pre-commit hook 등록 ─────────────────────────────────────────────
step "9. pre-commit 훅 등록"

if [[ -d ".git" ]]; then
    if command -v pre-commit &>/dev/null; then
        pre-commit install --hook-type pre-commit --hook-type pre-push   # pre-push: 영수증 대조 등
        success "pre-commit 훅 등록 완료 (.git/hooks/pre-commit + pre-push)"
    else
        warn "pre-commit이 설치되어 있지 않습니다."
    fi
else
    warn "git 레포가 아닙니다. 'git init' 후 'pre-commit install'을 수동 실행하세요."
fi

# ── 10. 초기 SwiftLint 검사 ──────────────────────────────────────────────
step "10. 초기 SwiftLint 검사"

if command -v swiftlint &>/dev/null; then
    if ask "  swiftlint lint를 실행할까요?"; then
        swiftlint lint 2>&1 && success "swiftlint: 위반 없음" \
            || warn "swiftlint: 위반이 남아 있습니다. 'swiftlint lint' 로 확인하세요."
    fi
else
    warn "SwiftLint가 설치되어 있지 않습니다. 검사를 건너뜁니다."
fi

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              Swift 품질 체계 적용 완료               ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  다음 단계:                                          ║"
echo "║  1. .swiftlint.yml included 경로 확인                ║"
echo "║  2. .swiftformat --swiftversion 확인                 ║"
echo "║  3. Claude 훅·pre-push: apply.sh --only hooks        ║"
echo "║  4. pre-commit run --all-files  (전체 검사)          ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  검증:                                               ║"
echo "║  swiftformat --lint .        # 포맷 검사             ║"
echo "║  swiftlint lint --strict     # 정적 분석             ║"
echo "║  swift test                  # 테스트                ║"
echo "║  periphery scan              # 데드코드 탐지         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
