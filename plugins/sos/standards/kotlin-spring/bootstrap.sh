#!/usr/bin/env bash
# kotlin-spring/bootstrap.sh — Kotlin/Spring Boot 프로젝트에 품질 체계 적용
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

# ─── Gradle wrapper 확인 ─────────────────────────────────────────────────────
step "1. Gradle wrapper 확인"
if [[ ! -f "gradlew" ]]; then
    warn "gradlew 없음. Gradle wrapper 설치 필요:"
    warn "  gradle wrapper --gradle-version 8.8"
    exit 1
fi
success "Gradle wrapper 발견"

# ─── build.gradle.kts에 품질 플러그인 추가 ────────────────────────────────────
step "2. build.gradle.kts — 품질 플러그인 추가"

if [[ ! -f "build.gradle.kts" ]]; then
    warn "build.gradle.kts 없음. build.gradle (Groovy)도 지원하려면 수동으로 추가하세요."
else
    echo ""
    echo "  quality.gradle.kts를 프로젝트 루트에 복사합니다."
    echo "  그런 다음 quality.gradle.kts 내용을 build.gradle.kts 에 합치세요 — plugins 블록은 기존 블록에 합칩니다."
    echo "  (apply(from = \"quality.gradle.kts\") 로는 동작하지 않습니다 — README 「1. quality.gradle.kts 적용」)"
    echo ""

    if [[ -f "quality.gradle.kts" ]]; then
        warn "quality.gradle.kts 이미 존재합니다."
        if ask "  덮어쓸까요?"; then
            cp "$TPL_DIR/quality.gradle.kts" quality.gradle.kts
            success "quality.gradle.kts 업데이트 완료"
        fi
    else
        cp "$TPL_DIR/quality.gradle.kts" quality.gradle.kts
        success "quality.gradle.kts 복사 완료"
        echo ""
        warn "quality.gradle.kts 내용을 build.gradle.kts 에 합쳐야 합니다(plugins 블록 · kotlin { jvmToolchain } 은 기존 것과 하나로)."
    fi
fi

# ─── libs.versions.toml 병합 가이드 ──────────────────────────────────────────
step "3. gradle/libs.versions.toml — 버전 카탈로그"

if [[ -f "gradle/libs.versions.toml" ]]; then
    warn "libs.versions.toml 이미 존재합니다."
    echo "      → $TPL_DIR/libs-quality.versions.toml 을 직접 비교해 수동 병합하세요:"
    echo "        diff gradle/libs.versions.toml $TPL_DIR/libs-quality.versions.toml"
else
    mkdir -p gradle
    cp "$TPL_DIR/libs-quality.versions.toml" gradle/libs-quality.versions.toml
    success "gradle/libs-quality.versions.toml 복사 완료"
    info "기존 libs.versions.toml이 없으면 이름을 libs.versions.toml로 변경하세요."
fi

# ─── detekt.yml ──────────────────────────────────────────────────────────────
step "4. detekt.yml — 정적 분석 설정"

if [[ -f "detekt.yml" ]]; then
    warn "detekt.yml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/detekt.yml" detekt.yml
        success "detekt.yml 업데이트 완료"
    fi
else
    cp "$TPL_DIR/detekt.yml" detekt.yml
    success "detekt.yml 복사 완료"
fi

# ─── .editorconfig ───────────────────────────────────────────────────────────
step "5. .editorconfig"

if [[ -f ".editorconfig" ]]; then
    warn ".editorconfig 이미 존재합니다. 건너뜀."
    info "($TPL_DIR/.editorconfig 참고하여 수동 병합하세요)"
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
    success "scripts/coverage-gate.sh 생성 완료 (uv 필요 · 첫 적용: scripts/coverage-gate.sh <리포트> --write-baseline 후 .coverage-baseline 커밋)"
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

# ─── ArchUnit 테스트 복사 ─────────────────────────────────────────────────────
step "7. ArchitectureTest.kt (선택)"

echo ""
echo "  ArchUnit 아키텍처 규칙 테스트를 복사합니다."
echo "  복사 후 패키지명(BASE_PACKAGE)을 수정하세요."

TEST_DIR="src/test/kotlin"
if [[ -d "$TEST_DIR" ]] && ask "  $TEST_DIR/architecture/ArchitectureTest.kt 로 복사할까요?"; then
    mkdir -p "$TEST_DIR/architecture"
    cp "$TPL_DIR/ArchitectureTest.kt" "$TEST_DIR/architecture/ArchitectureTest.kt"
    success "ArchitectureTest.kt 복사 완료 (패키지명 수동 수정 필요)"
fi

# ─── detect-secrets baseline ─────────────────────────────────────────────────
step "8. detect-secrets baseline"

if command -v detect-secrets &>/dev/null || python3 -m detect_secrets --version &>/dev/null 2>&1; then
    if [[ -f ".secrets.baseline" ]]; then
        warn ".secrets.baseline 이미 존재합니다. 건너뜀."
    else
        python3 -m detect_secrets scan \
            --exclude-files ".*\.gradle" \
            --exclude-files "gradlew" \
            --exclude-files ".*\.jar" \
            --exclude-files "build/.*" \
            > .secrets.baseline
        success ".secrets.baseline 생성 완료"
    fi
else
    warn "detect-secrets 미설치. 아래 명령어로 설치 후 실행하세요:"
    warn "  pip install detect-secrets"
    warn "  detect-secrets scan --exclude-files 'build/.*' > .secrets.baseline"
fi

# ─── pre-commit install ───────────────────────────────────────────────────────
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

# ─── OWASP suppressions.xml 생성 ─────────────────────────────────────────────
if [[ ! -f "owasp-suppressions.xml" ]]; then
    cat > owasp-suppressions.xml << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <!--
    거짓 양성(false positive) CVE를 여기에 추가합니다.
    예시:
    <suppress>
        <notes><![CDATA[Spring Boot 자체 취약점이 아닌 오탐]]></notes>
        <cve>CVE-2023-XXXXX</cve>
    </suppress>
    -->
</suppressions>
XML
    success "owasp-suppressions.xml 생성 완료"
fi

# ─── 완료 ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Kotlin/Spring Boot 품질 체계 적용 완료             ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                              ║"
echo "║  1. quality.gradle.kts 내용을 build.gradle.kts 에 합치기    ║"
echo "║     (apply(from) 은 동작 안 함 · JDK 25 필요)                ║"
echo "║  2. libs.versions.toml에 품질 도구 버전 병합                 ║"
echo "║     (gradle/libs-quality.versions.toml 참고)                 ║"
echo "║  3. ArchitectureTest.kt 패키지명 수정 (BASE_PACKAGE)         ║"
echo "║  4. detekt.yml 프로젝트 패키지 경로 확인                     ║"
echo "║  5. pre-commit run --all-files  (전체 검사)                  ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                        ║"
echo "║  ./gradlew qualityCheck     # 전체 품질 검사                 ║"
echo "║  ./gradlew qualityFix       # ktlint 자동 수정               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
