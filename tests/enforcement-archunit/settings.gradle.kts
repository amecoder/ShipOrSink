// Fixture project for tests/enforcement-archunit.bats — runs the ArchUnit templates on real compiled classes.
// The test copies this directory to a temp folder, adds sample sources, and runs ./gradlew :<lang>:test.
rootProject.name = "enforcement-archunit"

dependencyResolutionManagement {
    repositories { mavenCentral() }
    versionCatalogs {
        // The Kotlin template's own catalog, so the tested ArchUnit version is the shipped one.
        create("quality") {
            from(files(providers.gradleProperty("qualityCatalog")
                .getOrElse("$settingsDir/../../kotlin-spring/templates/libs-quality.versions.toml")))
        }
    }
}

include("kotlin", "java")
