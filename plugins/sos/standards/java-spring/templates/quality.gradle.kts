// ──────────────────────────────────────────────────────────────────────────────
// quality.gradle.kts — Java/Spring Boot quality tooling integration
// Usage: merge this file's content into build.gradle.kts (merge the plugins block into yours).
//   apply(from = "quality.gradle.kts") does NOT work: an applied script plugin cannot use a plugins {}
//   block or the type-safe accessors below (checkstyle {}, spotbugs {} …) — verified on Gradle 9.8.2.
// Versions: newest stable releases (no pre-release), each published 7+ days before adoption — 2026-11-12.
// ──────────────────────────────────────────────────────────────────────────────

plugins {
    java
    checkstyle                                                   // code style (Google Java Style)
    id("com.github.spotbugs") version "6.5.13"                   // bug & security detection
    jacoco                                                       // coverage
    id("org.owasp.dependencycheck") version "13.0.0"             // CVE scanning
}

// ── JDK — latest LTS (Gradle downloads it if missing only when a toolchain resolver is configured) ─
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

// ── ArchUnit (architecture rules — copy ArchitectureTest.java to src/test/java) ─
dependencies {
    "testImplementation"("com.tngtech.archunit:archunit-junit5:1.5.1")
}

// ── Checkstyle (Google Java Style) ──────────────────────────────────────────
checkstyle {
    toolVersion = "14.4.0"
    configFile = file("${rootDir}/checkstyle.xml")
    maxErrors = 0
    maxWarnings = 0
    isIgnoreFailures = false
    isShowViolations = true
}

tasks.withType<Checkstyle>().configureEach {
    reports {
        xml.required.set(true)    // SonarQube / CI integration
        html.required.set(true)   // local review
        sarif.required.set(false)
    }
    // exclude generated code
    exclude("**/generated/**", "**/build/**")
}

// ── SpotBugs ────────────────────────────────────────────────────────────────
spotbugs {
    toolVersion.set("4.10.5")
    effort.set(com.github.spotbugs.snom.Effort.MAX)
    reportLevel.set(com.github.spotbugs.snom.Confidence.MEDIUM)
    excludeFilter.set(file("${rootDir}/spotbugs-exclude.xml"))
}

tasks.withType<com.github.spotbugs.snom.SpotBugsTask>().configureEach {
    reports {
        create("html") { required.set(true) }
        create("xml") { required.set(true) }
    }
}

// ── JaCoCo coverage ─────────────────────────────────────────────────────────
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
        xml.required.set(true)    // SonarQube / Codecov
        html.required.set(true)   // local review
        csv.required.set(false)
    }
    classDirectories.setFrom(coverageClasses)
}

tasks.jacocoTestCoverageVerification {
    dependsOn(tasks.jacocoTestReport)
    classDirectories.setFrom(coverageClasses)
    violationRules {
        rule {
            // project-wide minimum 80%
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.80".toBigDecimal()
            }
        }
        rule {
            // per-class minimum 75%
            element = "CLASS"
            excludes = listOf(
                "*.config.*",
                "*.entity.*",
                "*.dto.*",
                "*Application",
            )
            limit {
                counter = "LINE"
                value = "COVEREDRATIO"
                minimum = "0.75".toBigDecimal()
            }
        }
    }
}

// ── OWASP Dependency Check (CI only recommended — slow locally) ─────────────
dependencyCheck {
    format = org.owasp.dependencycheck.reporting.ReportGenerator.Format.ALL.name
    failBuildOnCVSS = 7.0f           // CVSS >= 7.0 fails the build
    suppressionFile = "${rootDir}/owasp-suppressions.xml"
    nvd {
        apiKey = System.getenv("NVD_API_KEY") ?: ""   // slow without API key
    }
    analyzers {
        assemblyEnabled = false
    }
}

// ── google-java-format task (optional, for manual use) ──────────────────────
tasks.register<Exec>("googleJavaFormat") {
    group = "formatting"
    description = "Format Java sources with google-java-format"
    commandLine(
        "bash", "-c",
        """
        if command -v google-java-format &>/dev/null; then
            find src -name '*.java' -not -path '*/generated/*' | \
                xargs google-java-format --replace --aosp
        else
            echo "[WARN] google-java-format not installed"
            echo "  brew install google-java-format"
            echo "  OR: https://github.com/google/google-java-format/releases"
        fi
        """.trimIndent()
    )
}

// ── Aggregate quality tasks ─────────────────────────────────────────────────
tasks.register("qualityCheck") {
    group = "verification"
    description = "checkstyle + spotbugs + test + jacoco verification"
    dependsOn(
        "checkstyleMain",
        "checkstyleTest",
        "spotbugsMain",
        "test",
        "jacocoTestReport",
        "jacocoTestCoverageVerification",
    )
    doLast {
        println("[OK] All quality checks passed!")
    }
}

tasks.register("qualityFix") {
    group = "verification"
    description = "google-java-format auto-fix + spotbugs check"
    dependsOn("googleJavaFormat", "spotbugsMain")
}

// include in default check task (./gradlew check)
tasks.check {
    dependsOn(
        "checkstyleMain",
        "spotbugsMain",
        "jacocoTestCoverageVerification",
    )
}
