package com.example.architecture   // ← 프로젝트 패키지로 변경

import com.tngtech.archunit.core.domain.JavaClasses
import com.tngtech.archunit.core.importer.ClassFileImporter
import com.tngtech.archunit.core.importer.ImportOption
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields
import com.tngtech.archunit.library.Architectures.onionArchitecture
import com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Controller
import org.springframework.stereotype.Repository
import org.springframework.stereotype.Service
import org.springframework.web.bind.annotation.RestController

/**
 * ArchUnit 기반 아키텍처 규칙 검증 — Onion(= Hexagonal/Clean) 구조.
 *
 * 패키지 구조 (BASE_PACKAGE 아래):
 *   domain.model..        도메인 모델 — 어떤 계층에도 의존하지 않는다
 *   domain.service..      도메인 서비스 — domain.model 만 쓴다
 *   application..         유스케이스 — domain 만 쓴다 (어댑터가 구현할 포트 인터페이스도 여기에)
 *   adapter.web..         웹 어댑터 (Controller)
 *   adapter.persistence.. 영속성 어댑터 (Repository)
 *
 * 의존은 바깥(adapter)에서 안쪽(domain)으로만 향한다. 도메인이 어댑터를 import 하면 실패하고,
 * 어댑터끼리도 서로 의존하면 실패한다.
 * onion 규칙은 위 패키지들 사이의 의존만 본다(config 등은 순환 규칙만 본다).
 * 계층 하나라도 클래스가 없으면 실패한다(패키지 이름 오타를 잡기 위해). 쓰지 않는 계층이 있으면
 * onionArchitecture() 뒤에 .withOptionalLayers(true) 를 붙인다 — 줄을 지워도 그 계층은 빈 계층으로 남는다.
 */
class ArchitectureTest {

    // Imported once per test class (JUnit creates a new instance per test method).
    companion object {
        private const val BASE_PACKAGE = "com.example"   // ← 프로젝트 베이스 패키지로 변경

        private val classes: JavaClasses = ClassFileImporter()
            .withImportOption(ImportOption.DoNotIncludeTests())
            .importPackages(BASE_PACKAGE)
    }

    // ── Onion 아키텍처 ──────────────────────────────────────────────────────

    @Test
    fun `onion architecture should be respected`() {
        onionArchitecture()
            .domainModels("$BASE_PACKAGE.domain.model..")
            .domainServices("$BASE_PACKAGE.domain.service..")
            .applicationServices("$BASE_PACKAGE.application..")
            .adapter("web", "$BASE_PACKAGE.adapter.web..")
            .adapter("persistence", "$BASE_PACKAGE.adapter.persistence..")
            .check(classes)
    }

    // ── 어노테이션 위치 규칙 ────────────────────────────────────────────────

    @Test
    fun `@Service classes should reside in application or domain service`() {
        classes()
            .that().areAnnotatedWith(Service::class.java)
            .should().resideInAnyPackage("$BASE_PACKAGE.application..", "$BASE_PACKAGE.domain.service..")
            .allowEmptyShould(true)
            .check(classes)
    }

    @Test
    fun `@Repository classes should reside in persistence adapter`() {
        classes()
            .that().areAnnotatedWith(Repository::class.java)
            .should().resideInAPackage("$BASE_PACKAGE.adapter.persistence..")
            .allowEmptyShould(true)
            .check(classes)
    }

    @Test
    fun `@Controller and @RestController classes should reside in web adapter`() {
        classes()
            .that().areAnnotatedWith(Controller::class.java)
            .or().areAnnotatedWith(RestController::class.java)
            .should().resideInAPackage("$BASE_PACKAGE.adapter.web..")
            .allowEmptyShould(true)
            .check(classes)
    }

    // ── 의존성 규칙 ──────────────────────────────────────────────────────────

    @Test
    fun `no field should use field injection`() {
        noFields()
            .should().beAnnotatedWith(Autowired::class.java)
            .because("Constructor injection should be used instead of field injection")
            .check(classes)
    }

    @Test
    fun `no cyclic dependencies between packages`() {
        slices()
            .matching("$BASE_PACKAGE.(*)..")
            .should().beFreeOfCycles()
            .check(classes)
    }

    // ── 네이밍 규칙 ──────────────────────────────────────────────────────────

    @Test
    fun `service classes should be named ending in Service`() {
        classes()
            .that().areAnnotatedWith(Service::class.java)
            .should().haveSimpleNameEndingWith("Service")
            .allowEmptyShould(true)
            .check(classes)
    }

    @Test
    fun `repository classes should be named ending in Repository`() {
        classes()
            .that().areAnnotatedWith(Repository::class.java)
            .should().haveSimpleNameEndingWith("Repository")
            .allowEmptyShould(true)
            .check(classes)
    }
}
