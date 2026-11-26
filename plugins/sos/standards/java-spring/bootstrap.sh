#!/usr/bin/env bash
# java-spring/bootstrap.sh — Java/Spring Boot project quality setup
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

# ─── Helpers ──────────────────────────────────────────────────────────────────
ask()     { read -r -p "$1 [y/N] " ans; [[ "${ans,,}" == "y" ]]; }
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
warn()    { echo "[WARN]  $*"; }
step()    { echo ""; echo "── $* ──────────────────────────────────────"; }

# ─── 1. Gradle wrapper check ─────────────────────────────────────────────────
step "1. Gradle wrapper 확인"
if [[ ! -f "gradlew" ]]; then
    warn "gradlew 없음. Gradle wrapper 설치 필요:"
    warn "  gradle wrapper --gradle-version 8.8"
    exit 1
fi
success "Gradle wrapper 발견"

# ─── 2. quality.gradle.kts ───────────────────────────────────────────────────
step "2. build.gradle.kts — 품질 플러그인 추가"

BUILD_FILE=""
if [[ -f "build.gradle.kts" ]]; then
    BUILD_FILE="build.gradle.kts"
elif [[ -f "build.gradle" ]]; then
    BUILD_FILE="build.gradle"
fi

if [[ -z "$BUILD_FILE" ]]; then
    warn "build.gradle.kts / build.gradle 없음. Gradle 프로젝트가 맞는지 확인하세요."
else
    echo ""
    echo "  quality.gradle.kts를 프로젝트 루트에 복사합니다."
    echo "  그런 다음 quality.gradle.kts 내용을 $BUILD_FILE 에 합치세요 — plugins 블록은 기존 블록에 합칩니다."
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
        warn "quality.gradle.kts 내용을 $BUILD_FILE 에 합쳐야 합니다(plugins 블록 · java { toolchain } 은 기존 것과 하나로)."
    fi
fi

# ─── 3. checkstyle.xml ───────────────────────────────────────────────────────
step "3. checkstyle.xml — Google Java Style 설정"

if [[ -f "checkstyle.xml" ]]; then
    warn "checkstyle.xml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/checkstyle.xml" checkstyle.xml
        success "checkstyle.xml 업데이트 완료"
    fi
else
    cp "$TPL_DIR/checkstyle.xml" checkstyle.xml
    success "checkstyle.xml 복사 완료"
fi

# ─── 4. spotbugs-exclude.xml ─────────────────────────────────────────────────
step "4. spotbugs-exclude.xml — SpotBugs 제외 필터"

if [[ -f "spotbugs-exclude.xml" ]]; then
    warn "spotbugs-exclude.xml 이미 존재합니다."
    if ask "  덮어쓸까요?"; then
        cp "$TPL_DIR/spotbugs-exclude.xml" spotbugs-exclude.xml
        success "spotbugs-exclude.xml 업데이트 완료"
    fi
else
    cp "$TPL_DIR/spotbugs-exclude.xml" spotbugs-exclude.xml
    success "spotbugs-exclude.xml 복사 완료"
fi

# ─── 5. .editorconfig ────────────────────────────────────────────────────────
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

# ─── ArchUnit test ──────────────────────────────────────────────────────────
# ArchitectureTest.java — onion 규칙(도메인 → 어댑터 의존 금지). 의존성은 quality.gradle.kts 의 archunit-junit5
TEST_DIR="src/test/java"
if [[ -d "$TEST_DIR" ]] && ask "  $TEST_DIR/architecture/ArchitectureTest.java 로 ArchUnit 규칙을 복사할까요?"; then
    mkdir -p "$TEST_DIR/architecture"
    cp "$TPL_DIR/ArchitectureTest.java" "$TEST_DIR/architecture/ArchitectureTest.java"
    success "ArchitectureTest.java 복사 완료 (package 와 BASE_PACKAGE 수동 수정 필요)"
fi

# ─── 6. .pre-commit-config.yaml ──────────────────────────────────────────────
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

# ─── 7. google-java-format check ─────────────────────────────────────────────
step "7. google-java-format 확인"

if command -v google-java-format &>/dev/null; then
    success "google-java-format 설치 확인"
else
    warn "google-java-format 미설치. 아래 명령어로 설치하세요:"
    warn "  macOS: brew install google-java-format"
    warn "  기타: https://github.com/google/google-java-format/releases"
fi

# ─── 8. detect-secrets baseline ───────────────────────────────────────────────
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

# ─── 9. pre-commit install ──────────────────────────────────────────────────
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

# ─── 10. OWASP suppressions.xml ──────────────────────────────────────────────
if [[ ! -f "owasp-suppressions.xml" ]]; then
    cat > owasp-suppressions.xml << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <!--
    Add false positive CVEs here.
    Example:
    <suppress>
        <notes><![CDATA[False positive - not applicable to this project]]></notes>
        <cve>CVE-2023-XXXXX</cve>
    </suppress>
    -->
</suppressions>
XML
    success "owasp-suppressions.xml 생성 완료"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Java/Spring Boot 품질 체계 적용 완료                ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  필수 후속 작업:                                               ║"
echo "║  1. quality.gradle.kts 내용을 $BUILD_FILE 에 합치기          ║"
echo "║     (plugins 블록에 버전 포함 — apply(from) 은 동작 안 함)     ║"
echo "║  2. JDK 25 설치 (템플릿 toolchain = 25, 최신 LTS)              ║"
echo "║  3. google-java-format 설치 (brew install google-java-format) ║"
echo "║  4. pre-commit run --all-files  (전체 검사)                   ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  검증:                                                         ║"
echo "║  ./gradlew qualityCheck     # 전체 품질 검사                  ║"
echo "║  ./gradlew qualityFix       # 자동 수정 + SpotBugs 검사       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
