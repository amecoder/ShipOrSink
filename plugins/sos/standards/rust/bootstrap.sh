#!/usr/bin/env bash
# rust/bootstrap.sh — Rust 프로젝트에 품질 체계 적용
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

# ── 헬퍼 ──────────────────────────────────────────────────────────────────
ask()     { read -r -p "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "── $* ──────────────────────────────────────"; }

# ── Rust 환경 확인 ─────────────────────────────────────────────────────────
step "1. Rust 환경 확인"
if ! command -v rustup &>/dev/null; then
    warn "rustup 명령어를 찾을 수 없습니다."
    warn "  https://rustup.rs/ 에서 rustup을 설치한 뒤 다시 실행하세요."
    echo ""
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi
RUST_VERSION=$(rustc --version 2>/dev/null || echo "unknown")
success "Rust 발견: $RUST_VERSION"

# Cargo.toml 확인
if [[ ! -f "Cargo.toml" ]]; then
    warn "Cargo.toml 없음. Rust 프로젝트가 아닌 디렉터리입니다."
    if ask "  cargo init을 실행할까요?"; then
        cargo init
        success "cargo init 완료"
    else
        warn "Cargo.toml 없이 계속합니다."
    fi
else
    PROJECT_NAME=$(grep -m1 '^name' Cargo.toml | sed 's/.*= *"\(.*\)"/\1/' || echo "unknown")
    success "Cargo.toml 발견: $PROJECT_NAME"
fi

# ── rustfmt 확인 ──────────────────────────────────────────────────────────
step "2. rustfmt (포매터) 확인"
if rustup component list --installed 2>/dev/null | grep -q rustfmt; then
    FMT_VERSION=$(rustfmt --version 2>/dev/null || echo "unknown")
    success "rustfmt 발견: $FMT_VERSION"
else
    warn "rustfmt 미설치"
    if ask "  rustup component add rustfmt 으로 설치할까요?"; then
        rustup component add rustfmt
        success "rustfmt 설치 완료"
    else
        warn "건너뜀. 나중에 수동으로 설치하세요."
    fi
fi

# ── clippy 확인 ───────────────────────────────────────────────────────────
step "3. clippy (린터) 확인"
if rustup component list --installed 2>/dev/null | grep -q clippy; then
    CLIPPY_VERSION=$(cargo clippy --version 2>/dev/null || echo "unknown")
    success "clippy 발견: $CLIPPY_VERSION"
else
    warn "clippy 미설치"
    if ask "  rustup component add clippy 로 설치할까요?"; then
        rustup component add clippy
        success "clippy 설치 완료"
    else
        warn "건너뜀. 나중에 수동으로 설치하세요."
    fi
fi

# ── cargo-audit 확인 ──────────────────────────────────────────────────────
step "4. cargo-audit 설치 확인 (보안 취약점 스캔)"
if command -v cargo-audit &>/dev/null; then
    AUDIT_VERSION=$(cargo audit --version 2>/dev/null || echo "unknown")
    success "cargo-audit 발견: $AUDIT_VERSION"
else
    info "cargo-audit 미설치 (RustSec Advisory DB 기반 CVE 스캔)"
    if ask "  cargo install cargo-audit 로 설치할까요?"; then
        cargo install cargo-audit
        success "cargo-audit 설치 완료"
    else
        info "건너뜀."
    fi
fi

# ── cargo-deny 확인 ──────────────────────────────────────────────────────
step "5. cargo-deny 설치 확인 (라이선스 + 취약점 + 중복 의존성)"
if command -v cargo-deny &>/dev/null; then
    DENY_VERSION=$(cargo deny --version 2>/dev/null || echo "unknown")
    success "cargo-deny 발견: $DENY_VERSION"
else
    info "cargo-deny 미설치 (라이선스/취약점/소스 통합 검사)"
    if ask "  cargo install cargo-deny 로 설치할까요?"; then
        cargo install cargo-deny
        success "cargo-deny 설치 완료"
    else
        info "건너뜀."
    fi
fi

# ── cargo-tarpaulin 확인 ────────────────────────────────────────────────
step "6. cargo-tarpaulin 설치 확인 (커버리지, 선택)"
if command -v cargo-tarpaulin &>/dev/null; then
    TARP_VERSION=$(cargo tarpaulin --version 2>/dev/null || echo "unknown")
    success "cargo-tarpaulin 발견: $TARP_VERSION"
else
    info "cargo-tarpaulin 미설치 (코드 커버리지 측정, Linux 전용)"
    info "크로스 플랫폼 대안: cargo install cargo-llvm-cov"
    if ask "  cargo install cargo-tarpaulin 로 설치할까요?"; then
        cargo install cargo-tarpaulin
        success "cargo-tarpaulin 설치 완료"
    else
        info "건너뜀."
    fi
fi

# ── clippy.toml ───────────────────────────────────────────────────────────
step "7. clippy.toml — Clippy 린트 설정"

if [[ -f "clippy.toml" ]]; then
    warn "clippy.toml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/clippy.toml" clippy.toml
        success "clippy.toml 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/clippy.toml 참고하여 수동 병합하세요."
    fi
else
    cp "$TPL_DIR/clippy.toml" clippy.toml
    success "clippy.toml 생성 완료"
fi

# ── rustfmt.toml ──────────────────────────────────────────────────────────
step "8. rustfmt.toml — 포매터 설정"

if [[ -f "rustfmt.toml" ]]; then
    warn "rustfmt.toml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/rustfmt.toml" rustfmt.toml
        success "rustfmt.toml 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/rustfmt.toml 참고하여 수동 병합하세요."
    fi
else
    cp "$TPL_DIR/rustfmt.toml" rustfmt.toml
    success "rustfmt.toml 생성 완료"
fi

# ── deny.toml ─────────────────────────────────────────────────────────────
step "9. deny.toml — cargo-deny 설정"

if [[ -f "deny.toml" ]]; then
    warn "deny.toml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/deny.toml" deny.toml
        success "deny.toml 업데이트 완료"
    else
        info "건너뜀. $TPL_DIR/deny.toml 참고하여 수동 병합하세요."
    fi
else
    cp "$TPL_DIR/deny.toml" deny.toml
    success "deny.toml 생성 완료"
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

# ── .pre-commit-config.yaml ──────────────────────────────────────────────
step "10. .pre-commit-config.yaml"

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

# ── detect-secrets baseline ──────────────────────────────────────────────
step "11. detect-secrets baseline"

if command -v detect-secrets &>/dev/null || python3 -m detect_secrets --version &>/dev/null 2>&1; then
    if [[ -f ".secrets.baseline" ]]; then
        warn ".secrets.baseline 이미 존재합니다. 건너뜀."
    else
        EXCLUDE_ARGS="--exclude-files target/.*"

        # shellcheck disable=SC2086
        python3 -m detect_secrets scan $EXCLUDE_ARGS > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    fi
else
    warn "detect-secrets 미설치. 아래 명령어로 설치 후 실행하세요:"
    warn "  pip install detect-secrets"
    warn "  detect-secrets scan --exclude-files 'target/.*' > .secrets.baseline"
fi

# ── pre-commit install ───────────────────────────────────────────────────
step "12. pre-commit 훅 등록"

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

# ── Cargo.toml [lints] 섹션 안내 ─────────────────────────────────────────
step "13. Cargo.toml [lints] 섹션 확인"

if [[ -f "Cargo.toml" ]]; then
    if grep -q '\[lints' Cargo.toml 2>/dev/null; then
        success "Cargo.toml에 [lints] 섹션이 이미 존재합니다."
    else
        warn "Cargo.toml에 [lints] 섹션이 없습니다."
        echo "      아래 내용을 Cargo.toml에 추가하세요:"
        echo ""
        echo "      [lints.clippy]"
        echo "      correctness = \"deny\""
        echo "      suspicious = \"deny\""
        echo "      style = \"warn\""
        echo "      complexity = \"warn\""
        echo "      perf = \"warn\""
        echo "      pedantic = { level = \"warn\", priority = -1 }"
        echo "      dbg_macro = \"deny\""
        echo "      unwrap_used = \"warn\""
        echo ""
        echo "      [lints.rust]"
        echo "      unsafe_code = \"deny\""
        echo "      missing_docs = \"warn\""
    fi
fi

# ── 초기 clippy 검사 ────────────────────────────────────────────────────
step "14. 초기 clippy 검사"

if rustup component list --installed 2>/dev/null | grep -q clippy; then
    if [[ -f "Cargo.toml" ]]; then
        RS_FILES=$(find . -name "*.rs" -not -path "./target/*" 2>/dev/null | head -1)
        if [[ -n "$RS_FILES" ]]; then
            if ask "  cargo clippy를 실행할까요?"; then
                cargo clippy --all-targets --all-features -- -D warnings \
                    && success "clippy: 위반 없음" \
                    || warn "clippy: 위반이 있습니다. 'cargo clippy --all-targets --all-features -- -D warnings' 로 확인하세요."
            fi
        else
            info "Rust 소스 파일 없음. 린트 건너뜀."
        fi
    else
        info "Cargo.toml 없음. 린트 건너뜀."
    fi
else
    info "clippy 미설치. 건너뜀."
fi

# ── 완료 ─────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║             Rust 품질 체계 적용 완료                         ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                              ║"
echo "║  1. Cargo.toml — [lints.clippy] 섹션 추가                   ║"
echo "║  2. clippy.toml — msrv, 복잡도 임계값 조정                  ║"
echo "║  3. deny.toml — 라이선스 허용 목록 확인                     ║"
echo "║  4. Claude 훅·pre-push: sos apply.sh --only hooks         ║"
echo "║  5. pre-commit run --all-files  (전체 검사)                  ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                        ║"
echo "║  cargo fmt -- --check           # 포맷 검증                 ║"
echo "║  cargo clippy -- -D warnings    # 린트                      ║"
echo "║  cargo test --all-features      # 테스트                    ║"
echo "║  cargo audit                    # CVE 스캔                  ║"
echo "║  cargo deny check               # 라이선스/취약점/소스      ║"
echo "║  cargo tarpaulin --out html     # 커버리지 (Linux)          ║"
echo "║  cargo llvm-cov --html          # 커버리지 (크로스 플랫폼)  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
