#!/usr/bin/env bats
# tests/enforcement-kotlin-gradle.bats — Kotlin 템플릿(quality.gradle.kts + libs-quality.versions.toml + detekt.yml)을 README 안내대로
# 합친 프로젝트가 실제 Gradle(Wrapper 9.8.2 — tests/enforcement-archunit 의 것)에서 동작하는지 판정한다.
#   정상 샘플은 ./gradlew check 통과(detekt · ktlint(소스·빌드 스크립트) · test · jacoco 검증이 실제로 돈다)
#   detekt 위반 · ktlint 위반 · 줄 커버리지 80% 미만은 각각 막힌다 · dto 패키지는 80% 검증에서 빠진다
# detekt 는 2.0.0-alpha.6(사용자 결정 2026-11-12 — 정식 1.23.8 은 JDK 25 위 Gradle 에서 실패).
# 템플릿 toolchain 이 JDK 25 라 JDK 25 가 있어야 한다(JAVA_HOME 또는 PATH 의 java · 없으면 로컬은 skip, CI 는 실패).

load helpers

KT_TPL="$REPO_ROOT/kotlin-spring/templates"
WRAPPER_FIX="$PROJECT_ROOT/tests/enforcement-archunit"
KOTLIN_PLUGIN_VERSION="2.4.21"   # the downstream project's own Kotlin plugin (not shipped by the template)

setup() {
    require_tool java
    local major want jv="java"
    want="$(sed -nE 's/.*jvmToolchain\(([0-9]+)\).*/\1/p' "$KT_TPL/quality.gradle.kts")"
    [ -z "${JAVA_HOME:-}" ] || jv="$JAVA_HOME/bin/java"
    major="$("$jv" -XshowSettings:properties -version 2>&1 | sed -nE 's/^[[:space:]]*java\.specification\.version = ([0-9]+).*/\1/p')"
    [ -n "$want" ] || { echo "no jvmToolchain in quality.gradle.kts" >&2; return 1; }
    if [ "${major:-0}" != "$want" ]; then
        [ "${TEMPLATE_TOOLS_REQUIRED:-0}" != "1" ] || { echo "JDK exactly $want required (found ${major:-unknown})" >&2; return 1; }
        skip "JDK exactly $want required for the template toolchain (found ${major:-unknown})"
    fi
}

# A project: version catalog = the template catalog, build.gradle.kts = the template with the project's
# kotlin("jvm") plugin added to its plugins block, plus repositories and JUnit; prints its path.
kt_proj() {
    local d
    d="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp "$WRAPPER_FIX/gradlew" "$d/"
    mkdir -p "$d/gradle/wrapper"
    cp "$WRAPPER_FIX/gradle/wrapper/gradle-wrapper.jar" "$WRAPPER_FIX/gradle/wrapper/gradle-wrapper.properties" "$d/gradle/wrapper/"
    cp "$KT_TPL/libs-quality.versions.toml" "$d/gradle/libs.versions.toml"
    cp "$KT_TPL/detekt.yml" "$d/"
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
        '<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd"/>' \
        > "$d/owasp-suppressions.xml"
    printf 'rootProject.name = "kprobe"\n' > "$d/settings.gradle.kts"
    {
        sed "0,/^plugins {\$/s//plugins {\n    kotlin(\"jvm\") version \"$KOTLIN_PLUGIN_VERSION\"/" "$KT_TPL/quality.gradle.kts"
        printf '%s\n' '' 'repositories { mavenCentral() }' 'dependencies {' \
            '    testImplementation(platform("org.junit:junit-bom:6.1.3"))' \
            '    testImplementation("org.junit.jupiter:junit-jupiter")' \
            '    testRuntimeOnly("org.junit.platform:junit-platform-launcher")' '}'
    } > "$d/build.gradle.kts"
    mkdir -p "$d/src/main/kotlin/demo" "$d/src/test/kotlin/demo"
    printf '%s\n' 'package demo' '' 'object Hello {' '    fun hi(name: String): String = "hi $name"' '}' \
        > "$d/src/main/kotlin/demo/Hello.kt"
    printf '%s\n' 'package demo' '' 'import org.junit.jupiter.api.Assertions.assertEquals' 'import org.junit.jupiter.api.Test' '' \
        'class HelloTest {' '    @Test' '    fun greets() {' '        assertEquals("hi a", Hello.hi("a"))' '    }' '}' \
        > "$d/src/test/kotlin/demo/HelloTest.kt"
    echo "$d"
}

gradle_run() { # dir task...
    local d="$1"; shift
    (cd "$d" && ./gradlew --no-daemon --console=plain "$@" 2>&1)
}

# A Kotlin object with N uncovered one-line functions (constant-free so detekt stays quiet).
kt_uncovered() { # file package N
    local i
    { printf 'package %s\n\nobject Uncovered {\n' "$2"
      for i in $(seq 1 "$3"); do printf '    fun u%d(x: Int): Int = x + %d\n\n' "$i" "$i"; done
      printf '}\n'; } > "$1"
}

@test "kotlin gradle: the merged template passes ./gradlew check (detektMain/Test, ktlint, test, jacoco run)" {
    local d; d="$(kt_proj)"
    run gradle_run "$d" check
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    local t
    for t in detektMain detektTest ktlintMainSourceSetCheck ktlintKotlinScriptCheck test jacocoTestReport jacocoTestCoverageVerification; do
        grep -qE "^> Task :$t( |$)" <<<"$output" || { echo "task $t did not run"; echo "$output"; return 1; }
    done
}

@test "kotlin gradle: a detekt finding fails the detekt task" {
    local d; d="$(kt_proj)"
    printf '%s\n' 'package demo' '' 'object Const {' '    fun answer(): Int = 42' '}' > "$d/src/main/kotlin/demo/Const.kt"
    run gradle_run "$d" detekt
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "FunctionOnlyReturningConstant" <<<"$output" || { echo "$output"; return 1; }
}

# LongParameterList needs type resolution in detekt 2.0 — it runs only in detektMain/detektTest, not plain `detekt`.
# So this proves ./gradlew check is wired to the type-resolution tasks (a plain-detekt check passes this sample).
@test "kotlin gradle: ./gradlew check runs type-resolution detekt rules (6 parameters fail LongParameterList)" {
    local d; d="$(kt_proj)"
    printf '%s\n' 'package demo' '' 'object Six {' '    fun sum(' '        a: Int,' '        b: Int,' '        c: Int,' '        d: Int,' \
        '        e: Int,' '        f: Int,' '    ): Int = a + b + c + d + e + f' '}' > "$d/src/main/kotlin/demo/Six.kt"
    run gradle_run "$d" check
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "LongParameterList" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin gradle: a ktlint violation fails ktlintMainSourceSetCheck" {
    local d; d="$(kt_proj)"
    printf '%s\n' 'package demo' '' 'object Spaced {' '    fun twice(x: Int): Int =  x * 2' '}' > "$d/src/main/kotlin/demo/Spaced.kt"
    run gradle_run "$d" ktlintMainSourceSetCheck
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "no-multi-spaces" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin gradle: line coverage below 80% fails jacocoTestCoverageVerification" {
    local d; d="$(kt_proj)"
    kt_uncovered "$d/src/main/kotlin/demo/Uncovered.kt" demo 8
    run gradle_run "$d" jacocoTestCoverageVerification
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qE "lines covered ratio is 0\.[0-9]+, but expected minimum is 0\.80" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin gradle: classes under dto are excluded from the 80% verification (not only from the report)" {
    local d; d="$(kt_proj)"
    mkdir -p "$d/src/main/kotlin/demo/dto"
    kt_uncovered "$d/src/main/kotlin/demo/dto/Uncovered.kt" demo.dto 12
    run gradle_run "$d" jacocoTestCoverageVerification
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
