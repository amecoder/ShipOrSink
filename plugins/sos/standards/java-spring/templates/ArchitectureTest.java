package com.example.architecture; // ← 프로젝트 패키지로 변경

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noFields;
import static com.tngtech.archunit.library.Architectures.onionArchitecture;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.stereotype.Repository;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.RestController;

/**
 * ArchUnit 기반 아키텍처 규칙 검증 — Onion(= Hexagonal/Clean) 구조.
 *
 * <p>패키지 구조 (BASE_PACKAGE 아래):
 *
 * <ul>
 *   <li>domain.model.. 도메인 모델 — 어떤 계층에도 의존하지 않는다
 *   <li>domain.service.. 도메인 서비스 — domain.model 만 쓴다
 *   <li>application.. 유스케이스 — domain 만 쓴다 (어댑터가 구현할 포트 인터페이스도 여기에)
 *   <li>adapter.web.. 웹 어댑터 (Controller)
 *   <li>adapter.persistence.. 영속성 어댑터 (Repository)
 * </ul>
 *
 * <p>의존은 바깥(adapter)에서 안쪽(domain)으로만 향한다. 도메인이 어댑터를 import 하면 실패하고, 어댑터끼리도 서로
 * 의존하면 실패한다. onion 규칙은 위 패키지들 사이의 의존만 본다(config 등은 순환 규칙만 본다).
 *
 * <p>계층 하나라도 클래스가 없으면 실패한다(패키지 이름 오타를 잡기 위해). 쓰지 않는 계층이 있으면
 * onionArchitecture() 뒤에 .withOptionalLayers(true) 를 붙인다 — 줄을 지워도 그 계층은 빈 계층으로 남는다.
 */
class ArchitectureTest {

  private static final String BASE_PACKAGE = "com.example"; // ← 프로젝트 베이스 패키지로 변경

  // Imported once per test class (JUnit creates a new instance per test method).
  private static final JavaClasses IMPORTED_CLASSES =
      new ClassFileImporter()
          .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
          .importPackages(BASE_PACKAGE);

  // ── Onion 아키텍처 ──────────────────────────────────────────────────────

  @Test
  void onionArchitectureShouldBeRespected() {
    onionArchitecture()
        .domainModels(BASE_PACKAGE + ".domain.model..")
        .domainServices(BASE_PACKAGE + ".domain.service..")
        .applicationServices(BASE_PACKAGE + ".application..")
        .adapter("web", BASE_PACKAGE + ".adapter.web..")
        .adapter("persistence", BASE_PACKAGE + ".adapter.persistence..")
        .check(IMPORTED_CLASSES);
  }

  // ── 어노테이션 위치 규칙 ────────────────────────────────────────────────

  @Test
  void serviceClassesShouldResideInApplicationOrDomainService() {
    classes()
        .that()
        .areAnnotatedWith(Service.class)
        .should()
        .resideInAnyPackage(BASE_PACKAGE + ".application..", BASE_PACKAGE + ".domain.service..")
        .allowEmptyShould(true)
        .check(IMPORTED_CLASSES);
  }

  @Test
  void repositoryClassesShouldResideInPersistenceAdapter() {
    classes()
        .that()
        .areAnnotatedWith(Repository.class)
        .should()
        .resideInAPackage(BASE_PACKAGE + ".adapter.persistence..")
        .allowEmptyShould(true)
        .check(IMPORTED_CLASSES);
  }

  @Test
  void controllerClassesShouldResideInWebAdapter() {
    classes()
        .that()
        .areAnnotatedWith(Controller.class)
        .or()
        .areAnnotatedWith(RestController.class)
        .should()
        .resideInAPackage(BASE_PACKAGE + ".adapter.web..")
        .allowEmptyShould(true)
        .check(IMPORTED_CLASSES);
  }

  // ── 의존성 규칙 ──────────────────────────────────────────────────────────

  @Test
  void noFieldShouldUseFieldInjection() {
    noFields()
        .should()
        .beAnnotatedWith(Autowired.class)
        .because("Constructor injection should be used instead of field injection")
        .check(IMPORTED_CLASSES);
  }

  @Test
  void noCyclicDependenciesBetweenPackages() {
    slices().matching(BASE_PACKAGE + ".(*)..").should().beFreeOfCycles().check(IMPORTED_CLASSES);
  }

  // ── 네이밍 규칙 ──────────────────────────────────────────────────────────

  @Test
  void serviceClassesShouldBeNamedEndingInService() {
    classes()
        .that()
        .areAnnotatedWith(Service.class)
        .should()
        .haveSimpleNameEndingWith("Service")
        .allowEmptyShould(true)
        .check(IMPORTED_CLASSES);
  }

  @Test
  void repositoryClassesShouldBeNamedEndingInRepository() {
    classes()
        .that()
        .areAnnotatedWith(Repository.class)
        .should()
        .haveSimpleNameEndingWith("Repository")
        .allowEmptyShould(true)
        .check(IMPORTED_CLASSES);
  }
}
