// ──────────────────────────────────────────────────────────────────────────────
// quality.gradle.kts — Kotlin/Spring Boot 품질 도구 통합 설정
// 사용법: 이 파일 내용을 build.gradle.kts 에 합친다(plugins 블록은 기존 블록에 합친다).
//   apply(from = "quality.gradle.kts") 로는 동작하지 않는다 — 따로 불러오는 스크립트는 plugins {} 와
//   detekt {} · ktlint {} 같은 타입 안전 접근자를 쓸 수 없다(Gradle 9.8.2 실측).
// 플러그인 버전은 libs-quality.versions.toml 을 gradle/libs.versions.toml 에 합쳐서 쓴다(alias).
// ──────────────────────────────────────────────────────────────────────────────

plugins {
    alias(libs.plugins.detekt) // 정적 분석
    alias(libs.plugins.ktlint) // 포매터
    jacoco // 커버리지
    alias(libs.plugins.owasp.check) // 보안 취약점 (CI 전용 권장)
}

// ── JDK — 최신 LTS ────────────────────────────────────────────────────────────
kotlin {
    jvmToolchain(25)
}

// ── detekt ────────────────────────────────────────────────────────────────────
detekt {
    config.setFrom(files("$rootDir/detekt.yml"))
    basePath.set(rootDir)
    parallel = true
    buildUponDefaultConfig = false

    source.setFrom(
        files(
            "src/main/kotlin",
            "src/main/java",
        ),
    )
}

// detekt 2.0.0-alpha.6 — the only line tested on JDK 25 (stable 1.23.8 fails when Gradle runs on JDK 25).
// User decision 2026-11-12: pre-release allowed for detekt only; move to 2.0.0 stable when released.
tasks.withType<dev.detekt.gradle.Detekt>().configureEach {
    reports {
        html.required.set(true)
        checkstyle.required.set(true) // SonarQube 연동용 (1.x 의 xml)
        sarif.required.set(false)
        markdown.required.set(false)
    }
    jvmTarget.set("25")
}

tasks.withType<dev.detekt.gradle.DetektCreateBaselineTask>().configureEach {
    jvmTarget.set("25")
}

// ── ktlint ────────────────────────────────────────────────────────────────────
ktlint {
    version.set("1.8.0")
    verbose.set(true)
    outputToConsole.set(true)
    coloredOutput.set(true)
    reporters {
        reporter(org.jlleitschuh.gradle.ktlint.reporter.ReporterType.PLAIN)
        reporter(org.jlleitschuh.gradle.ktlint.reporter.ReporterType.CHECKSTYLE)
    }
    filter {
        exclude("**/generated/**")
        exclude("**/build/**")
        include("**/kotlin/**")
    }
}

// ── JaCoCo 커버리지 ───────────────────────────────────────────────────────────
jacoco {
    toolVersion = "0.8.16"
}

tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
}

// Excluded from coverage (config, entity, dto, generated) — applied to BOTH the report and the 80% verification
// (the verification task has its own classDirectories; filtering only the report left the rule unfiltered).
val coverageClasses =
    sourceSets.main.get().output.classesDirs.asFileTree.matching {
        exclude(
            "**/config/**",
            "**/entity/**",
            "**/dto/**",
            "**/*Application*",
            "**/generated/**",
        )
    }

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true) // SonarQube / Codecov 연동
        html.required.set(true) // 로컬 확인용
        csv.required.set(false)
    }
    classDirectories.setFrom(coverageClasses)
}

tasks.jacocoTestCoverageVerification {
    dependsOn(tasks.jacocoTestReport)
    classDirectories.setFrom(coverageClasses)
    violationRules {
        rule {
            // 전체 프로젝트 80% 이상
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.80".toBigDecimal()
            }
        }
        rule {
            // 클래스 단위 75% 이상 (너무 엄격하지 않게)
            element = "CLASS"
            excludes =
                listOf(
                    "*.config.*",
                    "*.entity.*",
                    "*.dto.*",
                    "*Application",
                    "*ApplicationKt",
                )
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.75".toBigDecimal()
            }
        }
    }
}

// ── OWASP Dependency Check (CI에서만 실행 권장, 로컬은 느림) ──────────────────
dependencyCheck {
    format = org.owasp.dependencycheck.reporting.ReportGenerator.Format.ALL.name
    failBuildOnCVSS = 7.0f // CVSS 7.0 이상 취약점 → 빌드 실패
    suppressionFile = "$rootDir/owasp-suppressions.xml"
    nvd {
        apiKey = System.getenv("NVD_API_KEY") ?: "" // API 키 없으면 느림
    }
    analyzers {
        assemblyEnabled = false
    }
}

// ── 통합 검증 task ────────────────────────────────────────────────────────────
tasks.register("qualityCheck") {
    group = "verification"
    description = "ktlint + detekt + test + jacoco 통합 검증"
    dependsOn(
        "ktlintCheck",
        "detektMain", // detekt 2.0: type-resolution tasks run every rule; plain `detekt` skips ~40
        "detektTest",
        "test",
        "jacocoTestReport",
        "jacocoTestCoverageVerification",
    )
    doLast {
        println("✅ All quality checks passed!")
    }
}

tasks.register("qualityFix") {
    group = "verification"
    description = "ktlint 자동 수정 + detekt 검사"
    dependsOn("ktlintFormat", "detektMain", "detektTest")
}

// check task에 포함 (./gradlew check 시 자동 실행)
tasks.check {
    dependsOn(
        "detektMain", // detekt 2.0: type-resolution tasks run every rule; plain `detekt` skips ~40
        "detektTest",
        "ktlintCheck",
        "jacocoTestCoverageVerification",
    )
}
