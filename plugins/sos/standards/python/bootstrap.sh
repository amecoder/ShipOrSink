#!/usr/bin/env bash
# python/bootstrap.sh — Python/FastAPI 프로젝트에 품질 체계 적용
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PWD}"
VENV_DIR=".venv"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET_DIR="$2"; shift 2 ;;
        --venv)   VENV_DIR="$2";   shift 2 ;;
        *) shift ;;
    esac
done

TPL_DIR="$SCRIPT_DIR/templates"
cd "$TARGET_DIR"

# ─── 헬퍼 ──────────────────────────────────────────────────────────────────
ask() { read -r -p "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "── $* ──────────────────────────────────────"; }

# ─── venv / pip 확인 ────────────────────────────────────────────────────────
step "1. 가상환경 확인"
if [[ -d "$VENV_DIR" ]]; then
    PIP="$VENV_DIR/bin/pip"
    PYTHON="$VENV_DIR/bin/python"
    success "venv 발견: $VENV_DIR"
else
    warn "venv를 찾을 수 없습니다 ($VENV_DIR). 시스템 pip 사용."
    PIP="pip"
    PYTHON="python3"
fi

# ─── 도구 설치 ──────────────────────────────────────────────────────────────
step "2. 도구 설치 (pre-commit, detect-secrets)"
$PIP install --quiet pre-commit detect-secrets
success "pre-commit, detect-secrets 설치 완료"

# ─── pyproject.toml 품질 설정 병합 ──────────────────────────────────────────
step "3. pyproject.toml — Ruff / mypy 설정 병합"

if [[ ! -f "pyproject.toml" ]]; then
    warn "pyproject.toml 없음. 빈 파일로 생성합니다."
    echo "" > pyproject.toml
fi

# [tool.ruff] 섹션 존재 여부 확인
if grep -q '^\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
    warn "[tool.ruff] 섹션이 이미 있습니다."
    echo "      → templates/pyproject-quality.toml 을 직접 비교해 수동 병합하세요:"
    echo "        diff pyproject.toml $TPL_DIR/pyproject-quality.toml"
else
    echo ""
    echo "  다음 섹션을 pyproject.toml에 추가합니다:"
    echo "    [tool.ruff], [tool.ruff.lint], [tool.ruff.lint.mccabe],"
    echo "    [tool.ruff.lint.per-file-ignores], [tool.mypy], [tool.importlinter]"
    echo ""
    if ask "  추가할까요?"; then
        echo "" >> pyproject.toml
        cat "$TPL_DIR/pyproject-quality.toml" >> pyproject.toml
        success "pyproject.toml에 품질 설정 추가 완료"
    else
        info "건너뜀. 나중에 수동으로 추가하세요: $TPL_DIR/pyproject-quality.toml"
    fi
fi

# ─── coverage gate ──────────────────────────────────────────────────────────
# scripts/coverage-gate.sh — CI 템플릿(common/ci-templates/ci-python.yml) 의 PR 단계 "Coverage gate (changed lines + ratchet)" 가 부른다(바뀐 줄 80% + 전체가 .coverage-baseline 아래로 떨어지지 않음)
if [[ -f "scripts/coverage-gate.sh" ]]; then
    warn "scripts/coverage-gate.sh 이미 존재합니다. 건너뜀."
else
    mkdir -p scripts
    cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh
    chmod +x scripts/coverage-gate.sh
    success "scripts/coverage-gate.sh 생성 완료 (uv 또는 pipx 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
fi

# ─── .pre-commit-config.yaml ────────────────────────────────────────────────
step "4. .pre-commit-config.yaml"

RUFF_VERSION=""
if command -v ruff &>/dev/null; then
    RUFF_VERSION=$(ruff --version 2>/dev/null | awk '{print $2}')
elif [[ -x "$VENV_DIR/bin/ruff" ]]; then
    RUFF_VERSION=$("$VENV_DIR/bin/ruff" --version 2>/dev/null | awk '{print $2}')
fi

if [[ -f ".pre-commit-config.yaml" ]]; then
    warn ".pre-commit-config.yaml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
        success ".pre-commit-config.yaml 복사 완료"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/.pre-commit-config.yaml" .pre-commit-config.yaml
    success ".pre-commit-config.yaml 생성 완료"
fi

# ruff 버전 자동 치환
if [[ -n "$RUFF_VERSION" ]]; then
    sed -i.bak "s/rev: v0\.14\.14/rev: v$RUFF_VERSION/" .pre-commit-config.yaml \
        && rm -f .pre-commit-config.yaml.bak
    success "ruff 버전을 v$RUFF_VERSION 으로 자동 설정"
else
    warn "ruff를 찾을 수 없습니다. .pre-commit-config.yaml의 rev 값을 직접 수정하세요."
fi

# ─── .secrets.baseline ──────────────────────────────────────────────────────
step "5. detect-secrets baseline 생성"

if [[ -f ".secrets.baseline" ]]; then
    warn ".secrets.baseline 이미 존재합니다. 건너뜀."
else
    EXCLUDE_ARGS=""
    [[ -d "tests"    ]] && EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-files tests/.*"
    [[ -d "examples" ]] && EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-files examples/.*"
    [[ -d ".venv"    ]] && EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-files .venv/.*"

    # shellcheck disable=SC2086
    $PYTHON -m detect_secrets scan $EXCLUDE_ARGS > .secrets.baseline
    success ".secrets.baseline 생성 완료"
fi

# ─── pre-commit install ──────────────────────────────────────────────────────
step "6. pre-commit 훅 등록"

if [[ -d ".git" ]]; then
    $PYTHON -m pre_commit install --hook-type pre-commit --hook-type pre-push   # pre-push: 영수증 대조 등
    success "pre-commit 훅 등록 완료 (.git/hooks/pre-commit + pre-push)"
else
    warn "git 레포가 아닙니다. 'git init' 후 'pre-commit install'을 수동 실행하세요."
fi

# ─── 초기 전체 검사 ─────────────────────────────────────────────────────────
step "7. 초기 ruff 검사"

RUFF_BIN=""
[[ -x "$VENV_DIR/bin/ruff" ]] && RUFF_BIN="$VENV_DIR/bin/ruff"
command -v ruff &>/dev/null && RUFF_BIN="ruff"

if [[ -n "$RUFF_BIN" ]] && ask "  ruff --fix 를 실행할까요? (auto-fix 적용)"; then
    SRC_DIRS=""
    [[ -d "src" ]]   && SRC_DIRS="$SRC_DIRS src/"
    [[ -d "tests" ]] && SRC_DIRS="$SRC_DIRS tests/"
    [[ -z "$SRC_DIRS" ]] && SRC_DIRS="."

    # shellcheck disable=SC2086
    $RUFF_BIN check --fix $SRC_DIRS && success "ruff: 위반 없음" \
        || warn "ruff: 수동 수정이 필요한 위반이 남아 있습니다. 'ruff check src/' 로 확인하세요."
fi

# ─── 완료 ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              Python 품질 체계 적용 완료              ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  다음 단계:                                          ║"
echo "║  1. pyproject.toml 병합 확인 (ruff/mypy 섹션)       ║"
echo "║  2. .pre-commit-config.yaml ruff rev 버전 확인       ║"
echo "║  3. Claude 훅·pre-push: apply.sh --only hooks        ║"
echo "║  4. pre-commit run --all-files  (전체 검사)          ║"
echo "║  5. [tool.importlinter] 의 \"app\" → 최상위 패키지     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
