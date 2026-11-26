#!/usr/bin/env bash
# csharp-dotnet/bootstrap.sh — C# / .NET 프로젝트에 품질 체계 적용
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

# ─── 헬퍼 ──────────────────────────────────────────────────────────────────
ask()     { read -r -p "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "── $* ──────────────────────────────────────"; }

# ─── .NET SDK 확인 ─────────────────────────────────────────────────────────
step "1. .NET SDK 확인"
if ! command -v dotnet &>/dev/null; then
    warn "dotnet 명령어를 찾을 수 없습니다."
    warn "  https://dotnet.microsoft.com/download 에서 .NET 8.0 이상을 설치하세요."
    exit 1
fi
DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
success ".NET SDK 발견: $DOTNET_VERSION"

# ─── 솔루션 / 프로젝트 확인 ─────────────────────────────────────────────────
step "2. 프로젝트 구조 확인"
SLN_FILE=$(find . -maxdepth 2 -name "*.sln" -print -quit 2>/dev/null || true)
CSPROJ_FILES=$(find . -maxdepth 3 -name "*.csproj" 2>/dev/null | head -5)

if [[ -z "$SLN_FILE" && -z "$CSPROJ_FILES" ]]; then
    warn ".sln 또는 .csproj 파일이 없습니다."
    if ask "  새 솔루션을 생성할까요? (dotnet new sln)"; then
        read -r -p "  솔루션 이름: " SLN_NAME
        dotnet new sln -n "$SLN_NAME"
        success "$SLN_NAME.sln 생성 완료"
    else
        warn ".sln/.csproj 없이 계속합니다."
    fi
else
    [[ -n "$SLN_FILE" ]] && success "솔루션 발견: $SLN_FILE"
    [[ -n "$CSPROJ_FILES" ]] && success ".csproj 발견: $(echo "$CSPROJ_FILES" | wc -l | tr -d ' ')개"
fi

# ─── global.json ─────────────────────────────────────────────────────────────
step "3. global.json — SDK 버전 고정"

if [[ -f "global.json" ]]; then
    warn "global.json 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/global.json" global.json
        success "global.json 업데이트 완료"
    fi
else
    cp "$TPL_DIR/global.json" global.json
    success "global.json 생성 완료 (SDK 8.0.404 고정)"
    info "  → 팀 SDK 버전에 맞게 sdk.version 수정하세요"
fi

# ─── Directory.Build.props ──────────────────────────────────────────────────
step "4. Directory.Build.props — 솔루션 전체 분석기 적용"

if [[ -f "Directory.Build.props" ]]; then
    warn "Directory.Build.props 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/Directory.Build.props" Directory.Build.props
        success "Directory.Build.props 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/Directory.Build.props 참고하여 수동 병합하세요."
        info "  → 특히 SonarLint.xml 을 넘기는 <AdditionalFiles Include=\"...SonarLint.xml\" /> 줄 — 없으면 복잡도 10 · 함수 80줄(Sonar 기본값)"
    fi
else
    cp "$TPL_DIR/Directory.Build.props" Directory.Build.props
    success "Directory.Build.props 생성 완료"
    info "  → Roslyn + Sonar + StyleCop + Roslynator + SecurityCodeScan 분석기 활성"
fi

# ─── stylecop.json ──────────────────────────────────────────────────────────
step "5. stylecop.json — StyleCop 설정"

if [[ -f "stylecop.json" ]]; then
    warn "stylecop.json 이미 존재합니다. 건너뜀."
else
    cp "$TPL_DIR/stylecop.json" stylecop.json
    success "stylecop.json 생성 완료"
    info "  → companyName 항목을 회사명으로 수정하세요"
fi

# SonarLint.xml — S1541(복잡도 15) · S138(함수 50줄) 한도. 없으면 Sonar 기본값 10 · 80 이 적용된다
if [[ -f "SonarLint.xml" ]]; then
    warn "SonarLint.xml 이미 존재합니다. 건너뜀 — S1541 15 · S138 50 인지 확인하세요."
else
    cp "$TPL_DIR/SonarLint.xml" SonarLint.xml
    success "SonarLint.xml 생성 완료 (복잡도 15 · 함수 50줄)"
fi

# ─── .editorconfig ──────────────────────────────────────────────────────────
step "6. .editorconfig — 코드 스타일 + Roslyn 규칙"

if [[ -f ".editorconfig" ]]; then
    warn ".editorconfig 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.editorconfig" .editorconfig
        success ".editorconfig 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/.editorconfig 참고하여 수동 병합하세요."
    fi
else
    cp "$TPL_DIR/.editorconfig" .editorconfig
    success ".editorconfig 생성 완료"
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

# ─── .pre-commit-config.yaml ──────────────────────────────────────────────────
step "7. .pre-commit-config.yaml"

if [[ -f ".pre-commit-config.yaml" ]]; then
    warn ".pre-commit-config.yaml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
        success ".pre-commit-config.yaml 복사 완료"
    fi
else
    cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
    success ".pre-commit-config.yaml 생성 완료"
fi

# ─── detect-secrets baseline ────────────────────────────────────────────────
step "8. detect-secrets baseline"

if command -v detect-secrets &>/dev/null || python3 -m detect_secrets --version &>/dev/null 2>&1; then
    if [[ -f ".secrets.baseline" ]]; then
        warn ".secrets.baseline 이미 존재합니다. 건너뜀."
    else
        EXCLUDE_ARGS="--exclude-files (bin|obj|packages)/.*"
        # shellcheck disable=SC2086
        python3 -m detect_secrets scan $EXCLUDE_ARGS > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    fi
else
    warn "detect-secrets 미설치. 아래 명령어로 설치 후 실행하세요:"
    warn "  pip install detect-secrets"
fi

# ─── pre-commit install ──────────────────────────────────────────────────────
step "9. pre-commit 훅 등록"

if command -v pre-commit &>/dev/null || python3 -m pre_commit --version &>/dev/null 2>&1; then
    if [[ -d ".git" ]]; then
        python3 -m pre_commit install --hook-type pre-commit --hook-type pre-push   # pre-push: 영수증 대조 등
        success "pre-commit 훅 등록 완료 (commit + push)"
    else
        warn "git 레포가 아닙니다. 'git init' 후 'pre-commit install'을 수동 실행하세요."
    fi
else
    warn "pre-commit 미설치: pip install pre-commit"
fi

# ─── dotnet restore ──────────────────────────────────────────────────────────
step "10. dotnet restore"

if [[ -n "$SLN_FILE" || -n "$CSPROJ_FILES" ]]; then
    if ask "  dotnet restore을 실행할까요? (분석기 패키지 다운로드)"; then
        dotnet restore && success "restore 완료" || warn "restore 실패. 'dotnet restore' 수동 실행 필요."
    fi
else
    info "프로젝트 없음. 건너뜀."
fi

# ─── 초기 dotnet format ──────────────────────────────────────────────────────
step "11. 초기 dotnet format 검사"

if [[ -n "$SLN_FILE" || -n "$CSPROJ_FILES" ]]; then
    if ask "  dotnet format을 실행할까요?"; then
        dotnet format --no-restore && success "format 완료" \
            || warn "format에서 변경사항이 있습니다."
    fi
fi

# ─── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          C# / .NET 품질 체계 적용 완료                       ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                              ║"
echo "║  1. global.json          — SDK 버전을 팀 표준으로 조정        ║"
echo "║  2. stylecop.json        — companyName 수정                   ║"
echo "║  3. .editorconfig        — 프로젝트별 규칙 조정               ║"
echo "║  4. dotnet build         — 분석기 경고 0개 확인               ║"
echo "║  5. dotnet test -p:CollectCoverage=true -p:Threshold=80       ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                        ║"
echo "║  dotnet format --verify-no-changes  # 스타일 검증             ║"
echo "║  dotnet build -warnaserror          # 분석기 + 경고 차단      ║"
echo "║  dotnet test -p:Threshold=80        # 커버리지 80%            ║"
echo "║  dotnet list package --vulnerable   # CVE 스캔                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
