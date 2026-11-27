#!/usr/bin/env bash
# go/bootstrap.sh — Go 프로젝트에 품질 체계 적용
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

# ─── Go 환경 확인 ─────────────────────────────────────────────────────────
step "1. Go 환경 확인"
if ! command -v go &>/dev/null; then
    warn "go 명령어를 찾을 수 없습니다."
    warn "  https://go.dev/dl/ 에서 Go를 설치한 뒤 다시 실행하세요."
    exit 1
fi
GO_VERSION=$(go version | awk '{print $3}')
success "Go 발견: $GO_VERSION"

# go.mod 확인
if [[ ! -f "go.mod" ]]; then
    warn "go.mod 없음. Go 모듈이 아닌 디렉터리입니다."
    if ask "  go mod init을 실행할까요?"; then
        read -r -p "  모듈 경로 (예: github.com/user/project): " MOD_PATH
        go mod init "$MOD_PATH"
        success "go mod init $MOD_PATH 완료"
    else
        warn "go.mod 없이 계속합니다."
    fi
else
    success "go.mod 발견: $(head -1 go.mod)"
fi

# ─── golangci-lint 설치 확인 ────────────────────────────────────────────────
step "2. golangci-lint 설치 확인"
if command -v golangci-lint &>/dev/null; then
    LINT_VERSION=$(golangci-lint version --short 2>/dev/null || echo "unknown")
    success "golangci-lint 발견: v$LINT_VERSION"
else
    warn "golangci-lint 미설치"
    echo "  설치 방법 (택 1):"
    echo "    brew install golangci-lint"
    echo "    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest"
    echo "    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh | sh -s -- -b \$(go env GOPATH)/bin"
    echo ""
    if ask "  'go install'로 설치할까요?"; then
        go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
        success "golangci-lint 설치 완료"
    else
        warn "건너뜀. 나중에 수동으로 설치하세요."
    fi
fi

# ─── gofumpt 설치 확인 ──────────────────────────────────────────────────────
step "3. gofumpt 설치 확인"
if command -v gofumpt &>/dev/null; then
    success "gofumpt 발견"
else
    warn "gofumpt 미설치"
    echo "  설치 방법: go install mvdan.cc/gofumpt@latest"
    echo ""
    if ask "  설치할까요?"; then
        go install mvdan.cc/gofumpt@latest
        success "gofumpt 설치 완료"
    else
        warn "건너뜀. 나중에 수동으로 설치하세요."
    fi
fi

# ─── gosec 설치 확인 ─────────────────────────────────────────────────────────
step "4. gosec 설치 확인 (선택)"
if command -v gosec &>/dev/null; then
    success "gosec 발견"
else
    info "gosec 미설치 (보안 스캔 도구, pre-push 훅에서 사용)"
    if ask "  설치할까요?"; then
        go install github.com/securego/gosec/v2/cmd/gosec@latest
        success "gosec 설치 완료"
    else
        info "건너뜀."
    fi
fi

# ─── govulncheck 설치 확인 ────────────────────────────────────────────────────
step "5. govulncheck 설치 확인 (선택)"
if command -v govulncheck &>/dev/null; then
    success "govulncheck 발견"
else
    info "govulncheck 미설치 (Go 공식 CVE 스캐너, pre-push 훅에서 사용)"
    if ask "  설치할까요?"; then
        go install golang.org/x/vuln/cmd/govulncheck@latest
        success "govulncheck 설치 완료"
    else
        info "건너뜀."
    fi
fi

# ─── .golangci.yml ──────────────────────────────────────────────────────────
step "6. .golangci.yml — golangci-lint v2 설정"

if [[ -f ".golangci.yml" ]]; then
    warn ".golangci.yml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.golangci.yml" .golangci.yml
        success ".golangci.yml 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/.golangci.yml 참고하여 수동 병합하세요."
    fi
else
    cp "$TPL_DIR/.golangci.yml" .golangci.yml
    success ".golangci.yml 생성 완료"
fi

# ─── .editorconfig ──────────────────────────────────────────────────────────
step "7. .editorconfig"

if [[ -f ".editorconfig" ]]; then
    warn ".editorconfig 이미 존재합니다. 건너뜀."
    info "($TPL_DIR/.editorconfig 참고하여 수동 병합하세요)"
else
    cp "$TPL_DIR/.editorconfig" .editorconfig
    success ".editorconfig 생성 완료"
fi

# ─── coverage gate ──────────────────────────────────────────────────────────
# scripts/coverage-gate.sh — CI 템플릿(common/ci-templates/ci-go.yml) 의 PR 단계 "Coverage gate (changed lines + ratchet)" 가 부른다(바뀐 줄 80% + 전체가 .coverage-baseline 아래로 떨어지지 않음)
if [[ -f "scripts/coverage-gate.sh" ]]; then
    warn "scripts/coverage-gate.sh 이미 존재합니다. 건너뜀."
else
    mkdir -p scripts
    cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh
    chmod +x scripts/coverage-gate.sh
    success "scripts/coverage-gate.sh 생성 완료 (uv 또는 pipx 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
fi

# ─── .pre-commit-config.yaml ──────────────────────────────────────────────────
step "8. .pre-commit-config.yaml"

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
step "9. detect-secrets baseline"

if command -v detect-secrets &>/dev/null || python3 -m detect_secrets --version &>/dev/null 2>&1; then
    if [[ -f ".secrets.baseline" ]]; then
        warn ".secrets.baseline 이미 존재합니다. 건너뜀."
    else
        EXCLUDE_ARGS="--exclude-files vendor/.*"
        [[ -d "testdata" ]] && EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-files testdata/.*"

        # shellcheck disable=SC2086
        python3 -m detect_secrets scan $EXCLUDE_ARGS > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    fi
else
    warn "detect-secrets 미설치. 아래 명령어로 설치 후 실행하세요:"
    warn "  pip install detect-secrets"
    warn "  detect-secrets scan --exclude-files 'vendor/.*' > .secrets.baseline"
fi

# ─── pre-commit install ──────────────────────────────────────────────────────
step "10. pre-commit 훅 등록"

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

# ─── go mod tidy ──────────────────────────────────────────────────────────────
step "11. go mod tidy"

if [[ -f "go.mod" ]]; then
    if ask "  go mod tidy를 실행할까요?"; then
        go mod tidy
        success "go mod tidy 완료"
    fi
else
    info "go.mod 없음. 건너뜀."
fi

# ─── 초기 golangci-lint 검사 ────────────────────────────────────────────────
step "12. 초기 golangci-lint 검사"

if command -v golangci-lint &>/dev/null; then
    # Check if there are any Go files
    GO_FILES=$(find . -name "*.go" -not -path "./vendor/*" 2>/dev/null | head -1)
    if [[ -n "$GO_FILES" ]]; then
        if ask "  golangci-lint run을 실행할까요?"; then
            golangci-lint run ./... && success "golangci-lint: 위반 없음" \
                || warn "golangci-lint: 위반이 있습니다. 'golangci-lint run ./...' 로 확인하세요."
        fi
    else
        info "Go 소스 파일 없음. 린트 건너뜀."
    fi
else
    info "golangci-lint 미설치. 건너뜀."
fi

# ─── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Go 품질 체계 적용 완료                        ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                              ║"
echo "║  1. .golangci.yml — 프로젝트에 맞게 린터 설정 조정           ║"
echo "║  2. Claude 훅·pre-push: sos apply.sh --only hooks         ║"
echo "║  3. pre-commit run --all-files  (전체 검사)                  ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                        ║"
echo "║  golangci-lint run ./...       # 전체 린트                   ║"
echo "║  golangci-lint run --fix ./... # 자동 수정                   ║"
echo "║  go test -race -cover ./...    # 테스트 + 커버리지           ║"
echo "║  gosec ./...                   # 보안 검사                   ║"
echo "║  govulncheck ./...             # 취약점 스캔                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
