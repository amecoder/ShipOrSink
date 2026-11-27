plugins {
    java
}

// The Java template pins ArchUnit in java-spring/templates/quality.gradle.kts — use that exact coordinate.
// Read lazily (only when the java test classpath resolves), so :kotlin:test does not depend on it.
val javaQualityScript = file(
    providers.gradleProperty("javaQualityScript")
        .getOrElse("$rootDir/../../java-spring/templates/quality.gradle.kts")
)
val archunit = provider {
    Regex("\"(com\\.tngtech\\.archunit:archunit-junit5:[^\"]+)\"")
        .find(javaQualityScript.readText())?.groupValues?.get(1)
        ?: error("no archunit-junit5 coordinate in $javaQualityScript")
}

dependencies {
    implementation(libs.spring.context)
    implementation(libs.spring.web)
    testImplementation(archunit)
    testImplementation(platform(libs.junit.bom))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging { events("passed", "failed"); exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL }
}
