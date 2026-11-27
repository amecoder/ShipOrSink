plugins {
    alias(libs.plugins.kotlin.jvm)
}

dependencies {
    implementation(libs.spring.context)
    implementation(libs.spring.web)
    testImplementation(quality.archunit.junit5)
    testImplementation(platform(libs.junit.bom))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    testLogging { events("passed", "failed"); exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL }
}
