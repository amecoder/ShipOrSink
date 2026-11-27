#!/usr/bin/env bash
# bootstrap.sh — 언어 자동 감지 후 품질 체계 적용
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${PWD}"
LANG_OVERRIDE=""

# ─── 인자 파싱 ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)   LANG_OVERRIDE="$2"; shift 2 ;;
        --target) TARGET_DIR="$2";   shift 2 ;;
        --help|-h)
            echo "Usage: bootstrap.sh [--lang python|kotlin-spring|typescript-react|go|java-spring|rust|flutter-dart|swift|csharp-dotnet|ruby-rails] [--target /path/to/project]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── 언어 감지 ─────────────────────────────────────────────────────────────
# JVM — Kotlin 흔적(build.gradle.kts · src/main/kotlin · kotlin 플러그인 선언)이 있으면 kotlin-spring,
# 없이 build.gradle(Groovy) 또는 pom.xml 만 있으면 java-spring,
# settings.gradle(.kts) 만 있어 판단 근거가 없으면 unknown.
detect_jvm_language() {
    local dir="$1"
    if [[ -f "$dir/build.gradle.kts" || -d "$dir/src/main/kotlin" ]] \
        || grep -qsE "org\.jetbrains\.kotlin|kotlin\(|apply plugin: *['\"]kotlin|kotlin-maven-plugin" \
            "$dir/build.gradle" "$dir/pom.xml"; then
        echo "kotlin-spring"
    elif [[ -f "$dir/build.gradle" || -f "$dir/pom.xml" ]]; then
        echo "java-spring"
    else
        echo "unknown"
    fi
}

# 강한 마커(언어 고유 매니페스트)를 먼저 검사하고,
# package.json 같은 약한 마커는 마지막에 둔다.
# 예: Rails 앱에 package.json이 함께 있어도 Gemfile이 먼저 매치되어 ruby-rails로 분류.
detect_language() {
    local dir="$1"
    if   [[ -f "$dir/pyproject.toml" || -f "$dir/setup.py" || -f "$dir/requirements.txt" ]]; then
        echo "python"
    elif [[ -f "$dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$dir/pubspec.yaml" ]] && grep -q "flutter:" "$dir/pubspec.yaml" 2>/dev/null; then
        echo "flutter-dart"
    elif [[ -f "$dir/Package.swift" || -n "$(find "$dir" -maxdepth 1 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) -print -quit 2>/dev/null)" ]]; then
        echo "swift"
    elif [[ -f "$dir/build.gradle.kts" || -f "$dir/build.gradle" || -f "$dir/pom.xml" \
            || -f "$dir/settings.gradle.kts" || -f "$dir/settings.gradle" ]]; then
        detect_jvm_language "$dir"
    elif [[ -f "$dir/global.json" || -n "$(find "$dir" -maxdepth 2 \( -name '*.csproj' -o -name '*.sln' -o -name '*.fsproj' \) -print -quit 2>/dev/null)" ]]; then
        echo "csharp-dotnet"
    elif [[ -f "$dir/Gemfile" || -f "$dir/config.ru" || -f "$dir/Rakefile" ]]; then
        echo "ruby-rails"
    elif [[ -f "$dir/tsconfig.json" || -f "$dir/next.config.js" || -f "$dir/next.config.mjs" || -f "$dir/next.config.ts" || -f "$dir/package.json" ]]; then
        # 약한 마커 — Rails/Django 등 다른 언어가 함께 JS 도구를 쓰는 경우를 위해 마지막에 검사
        echo "typescript-react"
    else
        echo "unknown"
    fi
}

# LANG 은 로케일 환경변수다 — 덮어쓰면 자식 프로세스의 인코딩이 깨진다
TARGET_LANG="${LANG_OVERRIDE:-$(detect_language "$TARGET_DIR")}"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       sos standards bootstrap        ║"
echo "╠══════════════════════════════════════╣"
echo "║  언어  : $TARGET_LANG"
echo "║  경로  : $TARGET_DIR"
echo "╚══════════════════════════════════════╝"
echo ""

# ─── 분기 실행 ─────────────────────────────────────────────────────────────
case "$TARGET_LANG" in
    python)
        bash "$SCRIPT_DIR/python/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    typescript-react)
        bash "$SCRIPT_DIR/typescript-react/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    go)
        bash "$SCRIPT_DIR/go/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    kotlin-spring)
        bash "$SCRIPT_DIR/kotlin-spring/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    flutter-dart)
        bash "$SCRIPT_DIR/flutter-dart/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    swift)
        bash "$SCRIPT_DIR/swift/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    java-spring)
        bash "$SCRIPT_DIR/java-spring/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    rust)
        bash "$SCRIPT_DIR/rust/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    csharp-dotnet)
        bash "$SCRIPT_DIR/csharp-dotnet/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    ruby-rails)
        bash "$SCRIPT_DIR/ruby-rails/bootstrap.sh" --target "$TARGET_DIR"
        ;;
    unknown)
        echo "[ERROR] 프로젝트 유형을 감지할 수 없습니다."
        echo "        --lang 옵션으로 직접 지정하세요:"
        echo "        bash bootstrap.sh --lang python"
        exit 1
        ;;
esac
