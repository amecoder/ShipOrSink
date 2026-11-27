#!/usr/bin/env bats
# tests/enforcement-java-gradle.bats — Java 템플릿 quality.gradle.kts 를 README 안내대로 build.gradle.kts 에 합친 프로젝트가
# 실제 Gradle(Wrapper 9.8.2 — tests/enforcement-archunit 의 것을 쓴다)에서 동작하는지 판정한다.
#   정상 샘플은 ./gradlew check 통과(checkstyle · spotbugs · test · jacoco 검증이 실제로 돈다)
#   checkstyle 위반은 Gradle checkstyleMain 이 막는다 · 줄 커버리지 80% 미만은 jacocoTestCoverageVerification 이 막는다
# 템플릿의 toolchain 이 JDK 25 라 JDK 25 가 있어야 한다 — JAVA_HOME(있으면) 아니면 PATH 의 java 가 정확히 25 여야 한다
# (toolchain resolver 가 없어 다른 버전 JDK 로는 Gradle 이 25 를 찾지 못한다 · 없으면 로컬은 skip, CI 는 실패).
# 첫 실행은 Gradle 배포판 · 플러그인 · 의존성을 받는다(GRADLE_USER_HOME, 기본 ~/.gradle).

load helpers

JAVA_TPL="$REPO_ROOT/java-spring/templates"
WRAPPER_FIX="$PROJECT_ROOT/tests/enforcement-archunit"

setup() {
    require_tool java
    local major want
    want="$(sed -nE 's/.*JavaLanguageVersion\.of\(([0-9]+)\).*/\1/p' "$JAVA_TPL/quality.gradle.kts")"
    local jv="java"; [ -z "${JAVA_HOME:-}" ] || jv="$JAVA_HOME/bin/java"
    major="$("$jv" -XshowSettings:properties -version 2>&1 | sed -nE 's/^[[:space:]]*java\.specification\.version = ([0-9]+).*/\1/p')"
    [ -n "$want" ] || { echo "no toolchain languageVersion in quality.gradle.kts" >&2; return 1; }
    if [ "${major:-0}" != "$want" ]; then
        [ "${TEMPLATE_TOOLS_REQUIRED:-0}" != "1" ] || { echo "JDK exactly $want required (found ${major:-unknown})" >&2; return 1; }
        skip "JDK exactly $want required for the template toolchain (found ${major:-unknown})"
    fi
}

# A project whose build.gradle.kts is the template verbatim plus repositories and JUnit; prints its path.
java_proj() {
    local d
    d="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp "$WRAPPER_FIX/gradlew" "$d/"
    mkdir -p "$d/gradle/wrapper"
    cp "$WRAPPER_FIX/gradle/wrapper/gradle-wrapper.jar" "$WRAPPER_FIX/gradle/wrapper/gradle-wrapper.properties" "$d/gradle/wrapper/"
    cp "$JAVA_TPL/checkstyle.xml" "$JAVA_TPL/spotbugs-exclude.xml" "$d/"
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
        '<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd"/>' \
        > "$d/owasp-suppressions.xml"
    printf 'rootProject.name = "probe"\n' > "$d/settings.gradle.kts"
    {
        cat "$JAVA_TPL/quality.gradle.kts"
        printf '%s\n' '' 'repositories { mavenCentral() }' 'dependencies {' \
            '    testImplementation(platform("org.junit:junit-bom:6.1.3"))' \
            '    testImplementation("org.junit.jupiter:junit-jupiter")' \
            '    testRuntimeOnly("org.junit.platform:junit-platform-launcher")' '}'
    } > "$d/build.gradle.kts"
    mkdir -p "$d/src/main/java/demo" "$d/src/test/java/demo"
    printf '%s\n' 'package demo;' '' '/** Demo. */' 'public final class Hello {' '  private Hello() {}' '' \
        '  /**' '   * Greets.' '   *' '   * @return greeting' '   */' '  public static String hi() {' '    return "hi";' '  }' '}' \
        > "$d/src/main/java/demo/Hello.java"
    printf '%s\n' 'package demo;' '' 'import static org.junit.jupiter.api.Assertions.assertEquals;' '' \
        'import org.junit.jupiter.api.Test;' '' 'class HelloTest {' '  @Test' '  void greets() {' \
        '    assertEquals("hi", Hello.hi());' '  }' '}' > "$d/src/test/java/demo/HelloTest.java"
    echo "$d"
}

gradle_run() { # dir task...
    local d="$1"; shift
    (cd "$d" && ./gradlew --no-daemon --console=plain "$@" 2>&1)
}

@test "java gradle: the merged template passes ./gradlew check (checkstyle, spotbugs, test, jacoco run)" {
    local d; d="$(java_proj)"
    run gradle_run "$d" check
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    local t
    for t in checkstyleMain checkstyleTest spotbugsMain test jacocoTestReport jacocoTestCoverageVerification; do
        grep -qE "^> Task :$t( |$)" <<<"$output" || { echo "task $t did not run"; echo "$output"; return 1; }
    done
}

@test "java gradle: a checkstyle violation fails checkstyleMain" {
    local d; d="$(java_proj)"
    printf '%s\n' 'package demo;' '' 'import java.util.*;' '' '/** Star. */' 'public final class Star {' \
        '  private Star() {}' '' '  /**' '   * List.' '   *' '   * @return list' '   */' \
        '  public static List<String> list() {' '    return new ArrayList<>();' '  }' '}' > "$d/src/main/java/demo/Star.java"
    run gradle_run "$d" checkstyleMain
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "AvoidStarImport" <<<"$output" || { echo "$output"; return 1; }
}

@test "java gradle: line coverage below 80% fails jacocoTestCoverageVerification" {
    local d; d="$(java_proj)"
    local i body=""
    for i in $(seq 1 8); do
        body="$body  /**\n   * Unused $i.\n   *\n   * @return value\n   */\n  public static int u$i() {\n    return $i;\n  }\n\n"
    done
    printf 'package demo;\n\n/** Uncovered. */\npublic final class Uncovered {\n  private Uncovered() {}\n\n%b}\n' "$body" \
        > "$d/src/main/java/demo/Uncovered.java"
    run gradle_run "$d" jacocoTestCoverageVerification
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qE "lines covered ratio is 0\.[0-9]+, but expected minimum is 0\.80" <<<"$output" || { echo "$output"; return 1; }
}

@test "java gradle: a SpotBugs bug pattern fails spotbugsMain" {
    local d; d="$(java_proj)"
    printf '%s\n' 'package demo;' '' '/** Bug. */' 'public final class Bug {' '  private Bug() {}' '' '  /**' \
        '   * Compares.' '   *' '   * @param a value' '   * @return result' '   */' \
        '  public static boolean same(String a) {' '    return a == new String("x");' '  }' '}' > "$d/src/main/java/demo/Bug.java"
    run gradle_run "$d" spotbugsMain
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qE "SpotBugs ended with exit code|bugs? (were|was) found" <<<"$output" || { echo "$output"; return 1; }
}

@test "java gradle: classes under dto are excluded from the 80% verification (not only from the report)" {
    local d; d="$(java_proj)"
    mkdir -p "$d/src/main/java/demo/dto"
    local i body=""
    for i in $(seq 1 12); do
        body="$body  /**\n   * Unused $i.\n   *\n   * @return value\n   */\n  public static int u$i() {\n    return $i;\n  }\n\n"
    done
    printf 'package demo.dto;\n\n/** Dto. */\npublic final class Big {\n  private Big() {}\n\n%b}\n' "$body" > "$d/src/main/java/demo/dto/Big.java"
    run gradle_run "$d" jacocoTestCoverageVerification
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
