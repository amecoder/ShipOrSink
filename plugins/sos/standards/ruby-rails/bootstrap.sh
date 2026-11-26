#!/usr/bin/env bash
# ruby-rails/bootstrap.sh — Ruby/Rails 프로젝트에 품질 체계 적용
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

# ─── Ruby 환경 확인 ───────────────────────────────────────────────────────
step "1. Ruby 환경 확인"
if ! command -v ruby &>/dev/null; then
    warn "ruby 명령어를 찾을 수 없습니다."
    warn "  rbenv / asdf / mise / chruby 등으로 Ruby 3.3+ 설치 후 다시 실행하세요."
    exit 1
fi
RUBY_VERSION=$(ruby -v | awk '{print $2}')
success "Ruby 발견: $RUBY_VERSION"

if [[ -f "Gemfile" ]]; then
    success "Gemfile 발견"
else
    warn "Gemfile 없음. Ruby 프로젝트가 아니거나 새로 만들어야 합니다."
    if ask "  bundle init으로 Gemfile을 생성할까요?"; then
        bundle init
        success "Gemfile 생성 완료"
    fi
fi

# ─── 필수 gem 설치 안내 ────────────────────────────────────────────────────
step "2. 품질/보안 gem 설치 안내"
echo "  Gemfile에 다음 gem을 추가하세요 (group :development, :test):"
cat <<'EOF'

  group :development, :test do
    gem "rubocop", require: false
    gem "rubocop-rails-omakase", require: false   # .rubocop.yml inherit_gem
    gem "rubocop-rails", require: false
    gem "rubocop-performance", require: false
    gem "rubocop-rspec", require: false
    gem "rubocop-rake", require: false
    gem "rubocop-thread_safety", require: false
    gem "brakeman", require: false
    gem "bundler-audit", require: false
    gem "rspec-rails"             # Rails 프로젝트인 경우
    gem "simplecov", require: false
    gem "simplecov-cobertura", require: false   # .simplecov → coverage/coverage.xml (coverage-gate 훅)
    gem "erb_lint", require: false
  end

EOF

if ask "  bundle install을 실행할까요? (Gemfile 수정 후)"; then
    bundle install && success "bundle install 완료" || warn "bundle install 실패"
fi

# ─── .rubocop.yml ──────────────────────────────────────────────────────────
step "3. .rubocop.yml — RuboCop 설정 (전사 표준)"

if [[ -f ".rubocop.yml" ]]; then
    warn ".rubocop.yml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/.rubocop.yml" .rubocop.yml
        success ".rubocop.yml 업데이트 완료"
    fi
else
    cp "$TPL_DIR/.rubocop.yml" .rubocop.yml
    success ".rubocop.yml 생성 완료"
    info "  → TargetRubyVersion / TargetRailsVersion을 프로젝트에 맞게 조정하세요"
fi

# ─── .editorconfig ──────────────────────────────────────────────────────────
step "4. .editorconfig"

if [[ -f ".editorconfig" ]]; then
    warn ".editorconfig 이미 존재합니다. 건너뜀."
else
    cp "$TPL_DIR/.editorconfig" .editorconfig
    success ".editorconfig 생성 완료"
fi

# ─── .simplecov ──────────────────────────────────────────────────────────
step "5. .simplecov — SimpleCov 설정 (커버리지 >= 80%)"

if [[ -f ".simplecov" ]]; then
    warn ".simplecov 이미 존재합니다. 건너뜀."
else
    cp "$TPL_DIR/.simplecov" .simplecov
    success ".simplecov 생성 완료"
    info "  → spec_helper.rb 또는 test_helper.rb 최상단에 추가:"
    info "      require \"simplecov\""
    info "      SimpleCov.start"
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
step "6. .pre-commit-config.yaml"

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
step "7. detect-secrets baseline"

if command -v detect-secrets &>/dev/null || python3 -m detect_secrets --version &>/dev/null 2>&1; then
    if [[ -f ".secrets.baseline" ]]; then
        warn ".secrets.baseline 이미 존재합니다. 건너뜀."
    else
        EXCLUDE_ARGS="--exclude-files (vendor|tmp|log|storage|node_modules)/.*"
        # shellcheck disable=SC2086
        python3 -m detect_secrets scan $EXCLUDE_ARGS > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    fi
else
    warn "detect-secrets 미설치. 아래 명령어로 설치 후 실행하세요:"
    warn "  pip install detect-secrets"
fi

# ─── pre-commit install ──────────────────────────────────────────────────────
step "8. pre-commit 훅 등록"

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

# ─── 초기 RuboCop 검사 ─────────────────────────────────────────────────────
step "9. 초기 RuboCop 검사"

if command -v bundle &>/dev/null && [[ -f "Gemfile.lock" ]]; then
    if ask "  bundle exec rubocop을 실행할까요?"; then
        bundle exec rubocop && success "RuboCop: 위반 없음" \
            || warn "RuboCop: 위반이 있습니다. 'bundle exec rubocop --autocorrect' 로 자동 수정 가능."
    fi
fi

# ─── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          Ruby / Rails 품질 체계 적용 완료                    ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                              ║"
echo "║  1. Gemfile          — 위에 안내된 gem 추가                   ║"
echo "║  2. bundle install                                            ║"
echo "║  3. spec_helper.rb   — SimpleCov.start 추가                   ║"
echo "║  4. .rubocop.yml     — TargetRubyVersion 조정                ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                        ║"
echo "║  bundle exec rubocop                  # 린트                  ║"
echo "║  bundle exec rubocop --autocorrect    # 자동 수정             ║"
echo "║  bundle exec brakeman                 # Rails 보안            ║"
echo "║  bundle exec bundler-audit check      # CVE 스캔              ║"
echo "║  bundle exec rspec                    # 테스트 + 커버리지     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
