#!/usr/bin/env bash
# typescript-react/bootstrap.sh — TypeScript/React/Next.js 프로젝트에 품질 체계 적용
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

pm_add_dev() {
    case "$PKG_MGR" in
        pnpm) pnpm add -D --save-exact "$@" ;;   # exact: a later re-lock must not float past a peer range
        yarn) yarn add -D --exact "$@" ;;
        bun)  bun add -D --exact "$@" ;;
        *)    npm install -D -E "$@" ;;
    esac
}

pm_exec() {
    case "$PKG_MGR" in
        pnpm) pnpm exec "$@" ;;
        yarn) yarn exec "$@" ;;
        bun)  bunx "$@" ;;
        *)    npx "$@" ;;
    esac
}

husky_available() {
    [[ -x "node_modules/.bin/husky" ]] || command -v husky &>/dev/null
}

# husky init 후 pre-commit(lint-staged)·pre-push(테스트 영수증 대조) 훅을 쓴다.
# husky 가 없어 init 이 실패하면 경고하고 1 을 돌려준다 (set -e 로 죽지 않게 호출부가 if 로 받는다).
setup_husky_hooks() {
    if ! pm_exec husky init 2>/dev/null; then
        if husky_available; then
            mkdir -p .husky
        else
            warn "husky 가 설치되어 있지 않아 Husky 설정을 건너뜀."
            info "의존성 설치(다음 단계) 후 'husky init' 을 실행하고 이 단계를 다시 적용하세요."
            return 1
        fi
    fi

    case "$PKG_MGR" in
        pnpm) echo "pnpm exec lint-staged" > .husky/pre-commit ;;
        yarn) echo "yarn exec lint-staged" > .husky/pre-commit ;;
        bun)  echo "bunx lint-staged" > .husky/pre-commit ;;
        *)    echo "npx lint-staged" > .husky/pre-commit ;;
    esac

    # apply.sh --only hooks 가 배치한 .githooks/pre-push 가 있을 때만 실행 (git 훅 경로 설정 불필요)
    cat > .husky/pre-push <<'HOOK'
if [ -f .githooks/pre-push ]; then
    exec bash .githooks/pre-push "$@"
fi
HOOK
    success "Husky 훅 설정 완료 (pre-commit: lint-staged · pre-push: 테스트 영수증 대조)"
}

detect_tailwind_stylesheet() {
    local candidates=(
        "src/app/globals.css"
        "app/globals.css"
        "src/styles/globals.css"
        "styles/globals.css"
        "src/index.css"
        "src/main.css"
    )

    for file in "${candidates[@]}"; do
        [[ -f "$file" ]] && { echo "./$file"; return; }
    done

    echo ""
}

configure_tailwind_prettier() {
    [[ -f ".prettierrc" ]] || return 0
    grep -q "tailwindcss" package.json 2>/dev/null || return 0

    local stylesheet
    stylesheet="$(detect_tailwind_stylesheet)"
    [[ -z "$stylesheet" ]] && return 0

    node -e '
const fs = require("node:fs");
const path = ".prettierrc";
const config = JSON.parse(fs.readFileSync(path, "utf8"));
config.tailwindStylesheet = process.argv[1];
fs.writeFileSync(path, `${JSON.stringify(config, null, 2)}\n`);
' "$stylesheet"
    success "Tailwind v4 stylesheet 경로 설정: $stylesheet"
}

# ── 1. Node.js / package.json check ──────────────────────────────────────
step "1. Node.js 환경 확인"

if ! command -v node &>/dev/null; then
    warn "Node.js가 설치되어 있지 않습니다."
    warn "https://nodejs.org 에서 설치 후 다시 실행하세요."
    exit 1
fi

NODE_VERSION=$(node -v)
success "Node.js $NODE_VERSION 발견"

if [[ ! -f "package.json" ]]; then
    warn "package.json 없음. npm init으로 생성합니다."
    npm init -y
    success "package.json 생성 완료"
fi

# Detect package manager
PKG_MGR="npm"
if [[ -f "pnpm-lock.yaml" ]]; then
    PKG_MGR="pnpm"
elif [[ -f "yarn.lock" ]]; then
    PKG_MGR="yarn"
elif [[ -f "bun.lockb" || -f "bun.lock" ]]; then
    PKG_MGR="bun"
fi
info "패키지 매니저: $PKG_MGR"

# ── 2. ESLint config ─────────────────────────────────────────────────────
step "2. eslint.config.mjs — ESLint 9+ Flat Config"

if [[ -f "eslint.config.mjs" ]] || [[ -f "eslint.config.js" ]] || [[ -f ".eslintrc.json" ]] || [[ -f ".eslintrc.js" ]]; then
    warn "ESLint 설정 파일이 이미 존재합니다."
    if ask "  eslint.config.mjs로 덮어쓸까요?"; then
        # Remove legacy config files
        rm -f .eslintrc.json .eslintrc.js .eslintrc.yml .eslintrc
        cp "$TPL_DIR/eslint.config.mjs" eslint.config.mjs
        success "eslint.config.mjs 업데이트 완료 (레거시 설정 파일 제거됨)"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/eslint.config.mjs" eslint.config.mjs
    success "eslint.config.mjs 생성 완료"
fi

# ── 3. TypeScript strict options ──────────────────────────────────────────
step "3. tsconfig.json — strict 품질 옵션"

if [[ -f "tsconfig.json" ]]; then
    echo ""
    echo "  기존 tsconfig.json이 있습니다."
    echo "  다음 옵션을 compilerOptions에 병합하세요:"
    echo ""
    echo "    \"strict\": true,"
    echo "    \"noUncheckedIndexedAccess\": true,"
    echo "    \"noImplicitOverride\": true,"
    echo "    \"exactOptionalPropertyTypes\": true,"
    echo "    \"forceConsistentCasingInFileNames\": true"
    echo ""
    echo "  참조: $TPL_DIR/tsconfig-quality.json"
    echo ""
else
    warn "tsconfig.json이 없습니다."
    info "Next.js: 'npx next dev'를 실행하면 자동 생성됩니다."
    info "Vite: 'npm create vite@latest'로 프로젝트를 생성하세요."
fi

# ── 4. Prettier config ───────────────────────────────────────────────────
step "4. .prettierrc — Prettier 설정"

if [[ -f ".prettierrc" ]] || [[ -f ".prettierrc.json" ]] || [[ -f "prettier.config.mjs" ]]; then
    warn "Prettier 설정 파일이 이미 존재합니다."
    if ask "  .prettierrc로 덮어쓸까요?"; then
        rm -f .prettierrc.json prettier.config.mjs prettier.config.js
        cp "$TPL_DIR/.prettierrc" .prettierrc
        success ".prettierrc 업데이트 완료"
    else
        info "건너뜀."
    fi
else
    cp "$TPL_DIR/.prettierrc" .prettierrc
    success ".prettierrc 생성 완료"
fi

# Check if Tailwind CSS is used
if ! grep -q "tailwindcss" package.json 2>/dev/null; then
    warn "Tailwind CSS가 감지되지 않았습니다."
    info ".prettierrc에서 'prettier-plugin-tailwindcss' 플러그인을 제거하세요."
else
    configure_tailwind_prettier
fi

# ── 5. Vitest config ─────────────────────────────────────────────────────
step "5. vitest.config.ts — 테스트 + 커버리지"

if [[ -f "vitest.config.ts" ]] || [[ -f "vitest.config.js" ]]; then
    warn "Vitest 설정 파일이 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/vitest.config.ts" vitest.config.ts
        success "vitest.config.ts 업데이트 완료"
    fi
else
    cp "$TPL_DIR/vitest.config.ts" vitest.config.ts
    success "vitest.config.ts 생성 완료"
fi

# Create test setup file
if [[ ! -f "tests/setup.ts" ]]; then
    mkdir -p tests
    echo "import '@testing-library/jest-dom/vitest';" > tests/setup.ts
    success "tests/setup.ts 생성 완료"
fi

# ─── dependency-cruiser ─────────────────────────────────────────────────────
# .dependency-cruiser.cjs — 순환 의존 · 계층 방향(src/domain → 바깥 금지) 검사. CI lint 잡 "Dependency rules" 가 부른다
if [[ -f ".dependency-cruiser.cjs" ]] || [[ -f ".dependency-cruiser.js" ]] || [[ -f ".dependency-cruiser.json" ]]; then
    warn "dependency-cruiser 설정 파일이 이미 존재합니다. 건너뜀 (템플릿: $TPL_DIR/.dependency-cruiser.cjs)."
else
    cp "$TPL_DIR/.dependency-cruiser.cjs" .dependency-cruiser.cjs
    success ".dependency-cruiser.cjs 생성 완료 (순환 import · domain/application 계층 — src/ 아래 또는 루트)"
fi

# ─── coverage gate ──────────────────────────────────────────────────────────
# scripts/coverage-gate.sh — CI 템플릿(common/ci-templates/ci-typescript.yml) 의 PR 단계 "Coverage gate (changed lines + ratchet)" 가 부른다(바뀐 줄 80% + 전체가 .coverage-baseline 아래로 떨어지지 않음)
if [[ -f "scripts/coverage-gate.sh" ]]; then
    warn "scripts/coverage-gate.sh 이미 존재합니다. 건너뜀."
else
    mkdir -p scripts
    cp "$SCRIPT_DIR/../common/testing-templates/coverage-gate.sh" scripts/coverage-gate.sh
    chmod +x scripts/coverage-gate.sh
    success "scripts/coverage-gate.sh 생성 완료 (uv 또는 pipx 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
fi

# ── 6. Husky + lint-staged ───────────────────────────────────────────────
step "6. Husky + lint-staged — pre-commit · pre-push 훅"

if [[ -d ".husky" ]]; then
    warn ".husky 디렉터리가 이미 존재합니다. 건너뜀."
    info "$TPL_DIR/.husky-lint-staged 파일을 참고하여 수동 확인하세요."
else
    if [[ -d ".git" ]]; then
        echo ""
        echo "  Husky를 초기화하고 lint-staged pre-commit 훅을 설정합니다."
        echo ""
        if ask "  진행할까요?" && setup_husky_hooks; then
            # Add lint-staged config to package.json if not present
            if ! grep -q "lint-staged" package.json 2>/dev/null; then
                info "package.json에 lint-staged 설정을 수동으로 추가하세요:"
                echo '  "lint-staged": {'
                echo '    "*.{ts,tsx}": ["eslint --fix --no-warn-ignored", "prettier --write"],'
                echo '    "*.{json,md,yml,yaml}": ["prettier --write"],'
                echo '    "*.{css,scss}": ["prettier --write"]'
                echo '  }'
            fi
        fi
    else
        warn "git 레포가 아닙니다. 'git init' 후 Husky를 수동 설정하세요."
    fi
fi

# ── 7. Install dependencies ──────────────────────────────────────────────
step "7. 개발 의존성 설치"

echo ""
# Pinned dev dependencies — templates/dev-dependencies.txt (the exact set tests/enforcement.bats proves).
# Unpinned `latest` no longer installs together (eslint 10 vs eslint-plugin-jsx-a11y peer <=9 → ERESOLVE).
DEPS=()
while read -r spec tag || [[ -n "$spec" ]]; do   # `|| -n`: keep a last line without a newline
    [[ -z "$spec" || "$spec" == \#* ]] && continue
    if [[ "$tag" == "tailwind" ]] && ! grep -q "tailwindcss" package.json 2>/dev/null; then
        continue
    fi
    # "name": — a key, not a value like "keywords": ["typescript"]
    if [[ "$tag" == "if-missing" ]] && grep -qE "\"${spec%@*}\"[[:space:]]*:" package.json 2>/dev/null; then
        info "${spec%@*} 는 package.json 에 이미 있어 버전을 바꾸지 않습니다."
        continue
    fi
    DEPS+=("$spec")
done < "$TPL_DIR/dev-dependencies.txt"

echo "  다음 패키지를 설치합니다 (버전 고정 — $TPL_DIR/dev-dependencies.txt):"
echo ""
printf '    %s\n' "${DEPS[@]}"
echo ""

if ask "  설치를 진행할까요?"; then
    pm_add_dev "${DEPS[@]}"

    success "개발 의존성 설치 완료"
else
    info "건너뜀. 위 패키지를 나중에 수동 설치하세요."
fi

# ── 8. Initial lint check ────────────────────────────────────────────────
step "8. 초기 ESLint 검사"

if [[ -f "eslint.config.mjs" ]]; then
    if ask "  eslint --fix를 실행할까요? (auto-fix 적용)"; then
        SRC_DIRS=""
        [[ -d "src" ]] && SRC_DIRS="$SRC_DIRS src/"
        [[ -d "app" ]] && SRC_DIRS="$SRC_DIRS app/"
        [[ -d "components" ]] && SRC_DIRS="$SRC_DIRS components/"
        [[ -d "lib" ]] && SRC_DIRS="$SRC_DIRS lib/"
        [[ -z "$SRC_DIRS" ]] && SRC_DIRS="."

        # shellcheck disable=SC2086
        pm_exec eslint --fix $SRC_DIRS 2>&1 && success "eslint: 위반 없음" \
            || warn "eslint: 수동 수정이 필요한 위반이 남아 있습니다. '${PKG_MGR} exec eslint .' 로 확인하세요."
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "+==========================================================+"
echo "|      TypeScript / React / Next.js 품질 체계 적용 완료     |"
echo "+==========================================================+"
echo "|  다음 단계:                                               |"
echo "|  1. tsconfig.json에 strict 옵션 병합 확인                 |"
echo "|     (templates/tsconfig-quality.json 참고)                |"
echo "|  2. package.json에 lint-staged 설정 추가                  |"
echo "|  3. package.json에 scripts 추가 (lint, format, test 등)   |"
echo "|  4. Claude 훅·pre-push: apply.sh --only hooks             |"
echo "|  5. Tailwind 미사용 시 .prettierrc에서 플러그인 제거      |"
echo "+==========================================================+"
echo "|  검증:                                                    |"
case "$PKG_MGR" in
    pnpm) VERIFY_PREFIX="pnpm exec" ;;
    yarn) VERIFY_PREFIX="yarn exec" ;;
    bun)  VERIFY_PREFIX="bunx" ;;
    *)    VERIFY_PREFIX="npx" ;;
esac
printf "|  %-27s # 린트 검사                   |\n" "$VERIFY_PREFIX eslint ."
printf "|  %-27s # 포맷 검사                   |\n" "$VERIFY_PREFIX prettier --check ."
printf "|  %-27s # 타입 검사                   |\n" "$VERIFY_PREFIX tsc --noEmit"
printf "|  %-27s # 테스트 + 커버리지            |\n" "$VERIFY_PREFIX vitest run --coverage"
echo "+==========================================================+"
echo ""
