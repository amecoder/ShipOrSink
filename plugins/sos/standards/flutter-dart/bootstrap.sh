#!/usr/bin/env bash
# flutter-dart/bootstrap.sh — Flutter/Dart 프로젝트에 품질 체계 적용
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

# ── 1. Flutter SDK check ──────────────────────────────────────────────────
step "1. Flutter SDK 환경 확인"

if ! command -v flutter &>/dev/null; then
    warn "Flutter SDK가 설치되어 있지 않습니다."
    warn "https://docs.flutter.dev/get-started/install 에서 설치 후 다시 실행하세요."
    exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
success "$FLUTTER_VERSION"

if ! command -v dart &>/dev/null; then
    warn "dart 명령어를 찾을 수 없습니다. Flutter SDK PATH를 확인하세요."
    exit 1
fi

DART_VERSION=$(dart --version 2>&1)
success "$DART_VERSION"

# ── 2. pubspec.yaml check ────────────────────────────────────────────────
step "2. pubspec.yaml 확인"

if [[ ! -f "pubspec.yaml" ]]; then
    warn "pubspec.yaml 없음. Flutter 프로젝트 디렉터리에서 실행하세요."
    if ask "  flutter create로 새 프로젝트를 생성할까요?"; then
        PROJECT_NAME=$(basename "$TARGET_DIR" | tr '[:upper:]' '[:lower:]' | tr '-' '_')
        flutter create --project-name "$PROJECT_NAME" .
        success "Flutter 프로젝트 생성 완료"
    else
        exit 1
    fi
fi

success "pubspec.yaml 발견"

# ── 3. analysis_options.yaml ──────────────────────────────────────────────
step "3. analysis_options.yaml — strict 정적 분석"

if [[ -f "analysis_options.yaml" ]]; then
    warn "analysis_options.yaml이 이미 존재합니다."
    if ask "  very_good_analysis 기반 strict 설정으로 덮어쓸까요?"; then
        cp "$TPL_DIR/analysis_options.yaml" analysis_options.yaml
        success "analysis_options.yaml 업데이트 완료"
    else
        info "건너뜀."
        info "  → analyzer.exclude 에 \"tool/quality_metrics/**\" 를 추가하세요 — 없으면 dart analyze 가 품질 도구 패키지까지 분석한다"
    fi
else
    cp "$TPL_DIR/analysis_options.yaml" analysis_options.yaml
    success "analysis_options.yaml 생성 완료"
fi

# ── 4. dev_dependencies 확인 ──────────────────────────────────────────────
step "4. 개발 의존성 확인"

echo ""
echo "  다음 패키지가 pubspec.yaml의 dev_dependencies에 필요합니다:"
echo ""
echo "  [분석]    very_good_analysis: ^7.0.0"
echo "  [커스텀]  custom_lint: ^0.7.0"
echo "  [테스트]  mocktail: ^1.0.4"
echo ""

if ask "  flutter pub add로 설치할까요?"; then
    flutter pub add --dev very_good_analysis custom_lint mocktail 2>&1 \
        && success "dev_dependencies 설치 완료" \
        || warn "일부 패키지 설치 실패. pubspec.yaml을 직접 확인하세요."
else
    info "건너뜀. 위 패키지를 나중에 수동 설치하세요."
fi

# ─── coverage gate ──────────────────────────────────────────────────────────
# scripts/coverage-gate.sh — pre-push 훅 coverage-gate 가 부른다(바뀐 줄 80% + 전체가 .coverage-baseline 아래로 떨어지지 않음)
if [[ -f "scripts/coverage-gate.sh" ]]; then
    warn "scripts/coverage-gate.sh 이미 존재합니다. 건너뜀."
else
    mkdir -p scripts
    cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh
    chmod +x scripts/coverage-gate.sh
    success "scripts/coverage-gate.sh 생성 완료 (uv 또는 pipx 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
fi

# ── 5. pre-commit 설정 ───────────────────────────────────────────────────
step "5. .pre-commit-config.yaml"

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

# tool/quality_metrics — 훅 dart-metrics(복잡도 15 · 함수 50줄)와 flutter-test(커버리지 80%)가 부르는 도구
if [[ -d "tool/quality_metrics" ]]; then
    warn "tool/quality_metrics 이미 존재합니다. 건너뜀."
else
    mkdir -p tool
    cp -R "$TPL_DIR/tool/quality_metrics" tool/quality_metrics
    success "tool/quality_metrics 생성 완료 (Dart SDK 3.13 이상 — 낮으면 pubspec.yaml 의 analyzer 버전을 낮춘다)"
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
else
    warn "pip가 없습니다. pre-commit을 수동 설치하세요: pip install pre-commit detect-secrets"
fi

# ── 6. detect-secrets baseline ────────────────────────────────────────────
step "6. detect-secrets baseline 생성"

if [[ -f ".secrets.baseline" ]]; then
    warn ".secrets.baseline 이미 존재합니다. 건너뜀."
else
    if command -v detect-secrets &>/dev/null; then
        detect-secrets scan \
            --exclude-files 'build/.*' \
            --exclude-files '\.dart_tool/.*' \
            --exclude-files '\.flutter-plugins.*' \
            --exclude-files '.*\.g\.dart' \
            > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    else
        warn "detect-secrets가 설치되어 있지 않습니다. 'pip install detect-secrets' 후 수동 생성하세요."
    fi
fi

# ── 7. pre-commit hook 등록 ──────────────────────────────────────────────
step "7. pre-commit 훅 등록"

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

# ── 8. 초기 dart analyze ──────────────────────────────────────────────────
step "8. 초기 dart analyze 검사"

if ask "  dart analyze를 실행할까요?"; then
    dart analyze 2>&1 && success "dart analyze: 위반 없음" \
        || warn "dart analyze: 위반이 남아 있습니다. 'dart analyze' 로 확인하세요."
fi

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          Flutter / Dart 품질 체계 적용 완료           ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  다음 단계:                                          ║"
echo "║  1. pubspec.yaml에 very_good_analysis 확인            ║"
echo "║  2. analysis_options.yaml 커스터마이징                ║"
echo "║  3. Claude 훅·pre-push: apply.sh --only hooks        ║"
echo "║  4. pre-commit run --all-files  (전체 검사)          ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  검증:                                               ║"
echo "║  dart format --set-exit-if-changed .  # 포맷 검사    ║"
echo "║  dart analyze --fatal-infos           # 정적 분석    ║"
echo "║  flutter test --coverage              # 테스트+커버리지║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
