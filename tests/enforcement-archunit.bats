#!/usr/bin/env bats
# tests/enforcement-archunit.bats — Java·Kotlin ArchUnit 템플릿의 onion 규칙이 실제로 막는지 실행 결과로 판정 (로드맵 A10).
# 배포 템플릿 kotlin-spring/templates/ArchitectureTest.kt · java-spring/templates/ArchitectureTest.java 를 그대로
# fixture Gradle 프로젝트(tests/enforcement-archunit — Gradle Wrapper 9.8.2, 배포판 sha256 고정)에 넣고 ./gradlew test 로 돌린다.
#   ArchUnit 버전 — Kotlin 은 템플릿 libs-quality.versions.toml, Java 는 템플릿 quality.gradle.kts 의 좌표를 그대로 쓴다
#   정상 onion 샘플은 통과 · 도메인 → 어댑터 의존은 onion 규칙이 그 호출을 지목하며 실패시킨다
#   (순환 규칙도 함께 실패한다 — 어댑터 → application → domain 이 늘 있어서 domain → adapter 는 곧 순환이다)
#   반증: onion 규칙의 check 를 뺀 템플릿에서는 같은 위반에서 onion 테스트가 통과한다
# java(17 이상)가 PATH 에 있어야 한다. 첫 실행은 Gradle 배포판과 의존성을 받는다(GRADLE_USER_HOME, 기본 ~/.gradle).

load helpers

FIX="$PROJECT_ROOT/tests/enforcement-archunit"
KT_TPL="$REPO_ROOT/kotlin-spring/templates"
JAVA_TPL="$REPO_ROOT/java-spring/templates"

setup() {
    require_tool java
    # Gradle 9 · Spring 7 · JUnit 6 need JDK 17+ — fail with a readable reason instead of a Gradle stack trace.
    local major
    major="$(java -XshowSettings:properties -version 2>&1 | sed -nE 's/^[[:space:]]*java\.specification\.version = ([0-9]+).*/\1/p')"
    [ "${major:-0}" -ge 17 ] || { echo "JDK 17+ required for tests/enforcement-archunit (found: ${major:-unknown})" >&2; return 1; }
}

# --- sample sources (onion layout under com.example) -------------------------------------------

kt_clean() { # dir
    local s="$1/kotlin/src/main/kotlin/com/example"
    mkdir -p "$s/domain/model" "$s/domain/service" "$s/application" "$s/adapter/web" "$s/adapter/persistence"
    printf 'package com.example.domain.model\ndata class Order(val id: Long, val amount: Long)\n' > "$s/domain/model/Order.kt"
    printf 'package com.example.domain.service\nimport com.example.domain.model.Order\nclass PricingService { fun total(order: Order) = order.amount }\n' \
        > "$s/domain/service/PricingService.kt"
    printf 'package com.example.application\nimport com.example.domain.model.Order\ninterface OrderPort { fun find(id: Long): Order }\n' \
        > "$s/application/OrderPort.kt"
    printf '%s\n' 'package com.example.application' 'import com.example.domain.service.PricingService' \
        'import org.springframework.stereotype.Service' '@Service' \
        'class OrderService(private val port: OrderPort) { fun total(id: Long) = PricingService().total(port.find(id)) }' \
        > "$s/application/OrderService.kt"
    printf '%s\n' 'package com.example.adapter.persistence' 'import com.example.application.OrderPort' \
        'import com.example.domain.model.Order' 'import org.springframework.stereotype.Repository' '@Repository' \
        'class OrderRepository : OrderPort { override fun find(id: Long) = Order(id, 100) }' \
        > "$s/adapter/persistence/OrderRepository.kt"
    printf '%s\n' 'package com.example.adapter.web' 'import com.example.application.OrderService' \
        'import org.springframework.web.bind.annotation.RestController' '@RestController' \
        'class OrderController(private val service: OrderService) { fun total(id: Long) = service.total(id) }' \
        > "$s/adapter/web/OrderController.kt"
}

# Domain model calls an adapter class.
kt_domain_to_adapter() { # dir
    local s="$1/kotlin/src/main/kotlin/com/example"
    kt_clean "$1"
    printf 'package com.example.adapter.persistence\nobject JdbcClock { fun now() = 0L }\n' > "$s/adapter/persistence/JdbcClock.kt"
    printf '%s\n' 'package com.example.domain.model' 'import com.example.adapter.persistence.JdbcClock' \
        'data class Order(val id: Long, val amount: Long) { fun stamp() = JdbcClock.now() }' > "$s/domain/model/Order.kt"
}

java_clean() { # dir
    local s="$1/java/src/main/java/com/example"
    mkdir -p "$s/domain/model" "$s/domain/service" "$s/application" "$s/adapter/web" "$s/adapter/persistence"
    printf 'package com.example.domain.model;\npublic record Order(long id, long amount) {}\n' > "$s/domain/model/Order.java"
    printf '%s\n' 'package com.example.domain.service;' 'import com.example.domain.model.Order;' \
        'public class PricingService { public long total(Order order) { return order.amount(); } }' \
        > "$s/domain/service/PricingService.java"
    printf '%s\n' 'package com.example.application;' 'import com.example.domain.model.Order;' \
        'public interface OrderPort { Order find(long id); }' > "$s/application/OrderPort.java"
    printf '%s\n' 'package com.example.application;' 'import com.example.domain.service.PricingService;' \
        'import org.springframework.stereotype.Service;' '@Service' 'public class OrderService {' \
        '  private final OrderPort port;' '  public OrderService(OrderPort port) { this.port = port; }' \
        '  public long total(long id) { return new PricingService().total(port.find(id)); }' '}' \
        > "$s/application/OrderService.java"
    printf '%s\n' 'package com.example.adapter.persistence;' 'import com.example.application.OrderPort;' \
        'import com.example.domain.model.Order;' 'import org.springframework.stereotype.Repository;' '@Repository' \
        'public class OrderRepository implements OrderPort { public Order find(long id) { return new Order(id, 100); } }' \
        > "$s/adapter/persistence/OrderRepository.java"
    printf '%s\n' 'package com.example.adapter.web;' 'import com.example.application.OrderService;' \
        'import org.springframework.web.bind.annotation.RestController;' '@RestController' 'public class OrderController {' \
        '  private final OrderService service;' '  public OrderController(OrderService service) { this.service = service; }' \
        '  public long total(long id) { return service.total(id); }' '}' > "$s/adapter/web/OrderController.java"
}

java_domain_to_adapter() { # dir
    local s="$1/java/src/main/java/com/example"
    java_clean "$1"
    printf 'package com.example.adapter.persistence;\npublic class JdbcClock { public static long now() { return 0L; } }\n' \
        > "$s/adapter/persistence/JdbcClock.java"
    printf '%s\n' 'package com.example.domain.model;' 'import com.example.adapter.persistence.JdbcClock;' \
        'public record Order(long id, long amount) { public long stamp() { return JdbcClock.now(); } }' \
        > "$s/domain/model/Order.java"
}

# --- runner -------------------------------------------------------------------------------------

# A copy of the fixture project with the given test file in place; prints its path.
arch_proj() { # lang test-file
    local dir
    dir="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
    cp -r "$FIX/." "$dir/"
    # Drop local build state a developer may have left in the fixture (stale classes would mask a sample change).
    rm -rf "$dir/.gradle" "$dir/build" "$dir/kotlin/build" "$dir/java/build"
    case "$1" in
        kotlin) mkdir -p "$dir/kotlin/src/test/kotlin/com/example/architecture"
                cp "$2" "$dir/kotlin/src/test/kotlin/com/example/architecture/ArchitectureTest.kt" ;;
        java)   mkdir -p "$dir/java/src/test/java/com/example/architecture"
                cp "$2" "$dir/java/src/test/java/com/example/architecture/ArchitectureTest.java" ;;
    esac
    echo "$dir"
}

arch_test() { # dir lang
    (cd "$1" && ./gradlew --no-daemon --console=plain ":$2:test" \
        -PqualityCatalog="$KT_TPL/libs-quality.versions.toml" \
        -PjavaQualityScript="$JAVA_TPL/quality.gradle.kts" 2>&1)
}

# The template with the onion rule's check removed (the rule is built but never evaluated).
without_onion_check() { # template out
    awk '/onion( a|A)rchitecture( s|S)hould/ { inside = 1 }
         inside && /\.check\([A-Za-z_]+\)/ { sub(/\.check\([A-Za-z_]+\)/, ""); inside = 0 }
         { print }' "$1" > "$2"
}

ONION_KT='onion architecture should be respected() FAILED'
ONION_JAVA='onionArchitectureShouldBeRespected() FAILED'
# The violation line for the sample's call (the cycle rule prints the same line, so the counter checks the test name).
ONION_CALL='Method <com.example.domain.model.Order.stamp()> calls method <com.example.adapter.persistence.JdbcClock.now()>'

# --- Kotlin -------------------------------------------------------------------------------------

@test "kotlin: template passes a clean onion project (all rules evaluated)" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_clean "$d"
    run arch_test "$d" kotlin
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$(grep -c ' PASSED$' <<<"$output")" -eq 8 ] || { echo "$output"; return 1; }
}

@test "kotlin: domain -> adapter dependency fails the onion rule, naming the call" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_domain_to_adapter "$d"
    run arch_test "$d" kotlin
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "$ONION_KT" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "$ONION_CALL" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin (counter): without the onion check the onion test passes on the same violation" {
    without_onion_check "$KT_TPL/ArchitectureTest.kt" "$BATS_TEST_TMPDIR/ArchitectureTest.kt"
    if cmp -s "$KT_TPL/ArchitectureTest.kt" "$BATS_TEST_TMPDIR/ArchitectureTest.kt"; then echo "counter variant equals the template"; return 1; fi
    local d; d="$(arch_proj kotlin "$BATS_TEST_TMPDIR/ArchitectureTest.kt")"
    kt_domain_to_adapter "$d"
    run arch_test "$d" kotlin
    grep -qF "${ONION_KT% FAILED} PASSED" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin: a layer package with no classes (typo) fails the onion rule" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_clean "$d"
    local s="$d/kotlin/src/main/kotlin/com/example"
    mkdir -p "$s/domain/services"
    sed 's/^package com.example.domain.service$/package com.example.domain.services/' \
        "$s/domain/service/PricingService.kt" > "$s/domain/services/PricingService.kt"
    rm "$s/domain/service/PricingService.kt"
    sed_i 's/import com.example.domain.service.PricingService/import com.example.domain.services.PricingService/' \
        "$s/application/OrderService.kt"
    run arch_test "$d" kotlin
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "$ONION_KT" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "Layer 'domain service' is empty" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin: field injection fails" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_clean "$d"
    printf '%s\n' 'package com.example.adapter.web' 'import com.example.application.OrderService' \
        'import org.springframework.beans.factory.annotation.Autowired' \
        'class LegacyController { @Autowired lateinit var service: OrderService }' \
        > "$d/kotlin/src/main/kotlin/com/example/adapter/web/LegacyController.kt"
    run arch_test "$d" kotlin
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "no field should use field injection() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin: @Repository outside the persistence adapter with a wrong name fails location and naming rules" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_clean "$d"
    printf '%s\n' 'package com.example.application' 'import org.springframework.stereotype.Repository' \
        '@Repository' 'class OrderStore' > "$d/kotlin/src/main/kotlin/com/example/application/OrderStore.kt"
    run arch_test "$d" kotlin
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "@Repository classes should reside in persistence adapter() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "repository classes should be named ending in Repository() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin: @Service in an adapter with a wrong name and @RestController in application fail their rules" {
    local d; d="$(arch_proj kotlin "$KT_TPL/ArchitectureTest.kt")"
    kt_clean "$d"
    local s="$d/kotlin/src/main/kotlin/com/example"
    printf '%s\n' 'package com.example.adapter.web' 'import org.springframework.stereotype.Service' \
        '@Service' 'class OrderHandler' > "$s/adapter/web/OrderHandler.kt"
    printf '%s\n' 'package com.example.application' 'import org.springframework.web.bind.annotation.RestController' \
        '@RestController' 'class StatusController' > "$s/application/StatusController.kt"
    run arch_test "$d" kotlin
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "@Service classes should reside in application or domain service() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "service classes should be named ending in Service() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "@Controller and @RestController classes should reside in web adapter() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

@test "kotlin: a project without domain services passes with withOptionalLayers(true) (README advice)" {
    sed 's/^\([[:space:]]*\)onionArchitecture()$/\1onionArchitecture().withOptionalLayers(true)/' \
        "$KT_TPL/ArchitectureTest.kt" > "$BATS_TEST_TMPDIR/ArchitectureTest.kt"
    if cmp -s "$KT_TPL/ArchitectureTest.kt" "$BATS_TEST_TMPDIR/ArchitectureTest.kt"; then echo "no onionArchitecture() line"; return 1; fi
    local d; d="$(arch_proj kotlin "$BATS_TEST_TMPDIR/ArchitectureTest.kt")"
    kt_clean "$d"
    local s="$d/kotlin/src/main/kotlin/com/example"
    rm "$s/domain/service/PricingService.kt"
    printf '%s\n' 'package com.example.application' 'import org.springframework.stereotype.Service' '@Service' \
        'class OrderService(private val port: OrderPort) { fun total(id: Long) = port.find(id).amount }' \
        > "$s/application/OrderService.kt"
    run arch_test "$d" kotlin
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# --- Java ---------------------------------------------------------------------------------------

@test "java: template passes a clean onion project (all rules evaluated)" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_clean "$d"
    run arch_test "$d" java
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$(grep -c ' PASSED$' <<<"$output")" -eq 8 ] || { echo "$output"; return 1; }
}

@test "java: domain -> adapter dependency fails the onion rule, naming the call" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_domain_to_adapter "$d"
    run arch_test "$d" java
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "$ONION_JAVA" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "$ONION_CALL" <<<"$output" || { echo "$output"; return 1; }
}

@test "java (counter): without the onion check the onion test passes on the same violation" {
    without_onion_check "$JAVA_TPL/ArchitectureTest.java" "$BATS_TEST_TMPDIR/ArchitectureTest.java"
    if cmp -s "$JAVA_TPL/ArchitectureTest.java" "$BATS_TEST_TMPDIR/ArchitectureTest.java"; then echo "counter variant equals the template"; return 1; fi
    local d; d="$(arch_proj java "$BATS_TEST_TMPDIR/ArchitectureTest.java")"
    java_domain_to_adapter "$d"
    run arch_test "$d" java
    grep -qF "${ONION_JAVA% FAILED} PASSED" <<<"$output" || { echo "$output"; return 1; }
}

@test "java: a layer package with no classes (typo) fails the onion rule" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_clean "$d"
    local s="$d/java/src/main/java/com/example"
    mkdir -p "$s/domain/services"
    sed 's/^package com.example.domain.service;$/package com.example.domain.services;/' \
        "$s/domain/service/PricingService.java" > "$s/domain/services/PricingService.java"
    rm "$s/domain/service/PricingService.java"
    sed_i 's/import com.example.domain.service.PricingService;/import com.example.domain.services.PricingService;/' \
        "$s/application/OrderService.java"
    run arch_test "$d" java
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "$ONION_JAVA" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "Layer 'domain service' is empty" <<<"$output" || { echo "$output"; return 1; }
}

@test "java: field injection fails" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_clean "$d"
    printf '%s\n' 'package com.example.adapter.web;' 'import com.example.application.OrderService;' \
        'import org.springframework.beans.factory.annotation.Autowired;' \
        'public class LegacyController { @Autowired OrderService service; }' \
        > "$d/java/src/main/java/com/example/adapter/web/LegacyController.java"
    run arch_test "$d" java
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "noFieldShouldUseFieldInjection() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

@test "java: @Repository outside the persistence adapter with a wrong name fails location and naming rules" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_clean "$d"
    printf '%s\n' 'package com.example.application;' 'import org.springframework.stereotype.Repository;' \
        '@Repository' 'public class OrderStore {}' > "$d/java/src/main/java/com/example/application/OrderStore.java"
    run arch_test "$d" java
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "repositoryClassesShouldResideInPersistenceAdapter() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "repositoryClassesShouldBeNamedEndingInRepository() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

@test "java: @Service in an adapter with a wrong name and @RestController in application fail their rules" {
    local d; d="$(arch_proj java "$JAVA_TPL/ArchitectureTest.java")"
    java_clean "$d"
    local s="$d/java/src/main/java/com/example"
    printf '%s\n' 'package com.example.adapter.web;' 'import org.springframework.stereotype.Service;' \
        '@Service' 'public class OrderHandler {}' > "$s/adapter/web/OrderHandler.java"
    printf '%s\n' 'package com.example.application;' 'import org.springframework.web.bind.annotation.RestController;' \
        '@RestController' 'public class StatusController {}' > "$s/application/StatusController.java"
    run arch_test "$d" java
    [ "$status" -ne 0 ] || { echo "$output"; return 1; }
    grep -qF "serviceClassesShouldResideInApplicationOrDomainService() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "serviceClassesShouldBeNamedEndingInService() FAILED" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "controllerClassesShouldResideInWebAdapter() FAILED" <<<"$output" || { echo "$output"; return 1; }
}

# The template is copied into src/test/java, and the Gradle checkstyle plugin also checks test sources
# (checkstyleTest, maxErrors = 0) — so it must pass the shipped checkstyle.xml as is.
@test "java: the template passes the shipped checkstyle.xml" {
    local v jar
    v="$(sed -n '/^checkstyle {/,/^}/p' "$JAVA_TPL/quality.gradle.kts" | sed -nE 's/^[[:space:]]*toolVersion = "([0-9.]+)"$/\1/p')"
    jar="${CHECKSTYLE_JAR:-$HOME/.cache/dev-standards-tools/checkstyle-$v-all.jar}"
    if [ ! -f "$jar" ]; then
        [ "${TEMPLATE_TOOLS_REQUIRED:-0}" != "1" ] || { echo "required tool missing: $jar" >&2; return 1; }
        skip "checkstyle jar not found: $jar"
    fi
    run java -jar "$jar" -c "$JAVA_TPL/checkstyle.xml" "$JAVA_TPL/ArchitectureTest.java"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    ! grep -qF "[ERROR]" <<<"$output" || { echo "$output"; return 1; }
    grep -qF "Audit done." <<<"$output" || { echo "$output"; return 1; }
}

# --- wiring -------------------------------------------------------------------------------------

@test "Java and Kotlin templates pin the same ArchUnit version" {
    local kt java
    kt="$(sed -nE 's/^archunit[[:space:]]*=[[:space:]]*"([^"]+)"$/\1/p' "$KT_TPL/libs-quality.versions.toml")"
    java="$(sed -nE 's/.*"com\.tngtech\.archunit:archunit-junit5:([^"]+)".*/\1/p' "$JAVA_TPL/quality.gradle.kts")"
    [ -n "$kt" ] && [ "$kt" = "$java" ] || { echo "kotlin=$kt java=$java"; return 1; }
}

@test "bootstrap copies the ArchUnit template for both languages" {
    grep -qF 'ArchitectureTest.kt' "$REPO_ROOT/kotlin-spring/bootstrap.sh"
    grep -qF 'ArchitectureTest.java' "$REPO_ROOT/java-spring/bootstrap.sh"
}
