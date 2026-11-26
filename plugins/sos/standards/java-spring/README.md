# Java / Spring Boot 품질 체계

## 포함 도구

| 도구 | 역할 | Kotlin 대응 | Python 대응 |
|------|------|-------------|-------------|
| **Checkstyle** | 코드 스타일 (Google Java Style) | ktlint | ruff |
| **SpotBugs** | 버그/보안 정적 분석 | detekt | ruff + bandit |
| **JaCoCo** | 커버리지 (>= 80%) | JaCoCo (동일) | pytest-cov |
| **google-java-format** | 자동 포매터 | ktlint format | ruff format |
| **OWASP Dependency Check** | 취약점 스캔 | OWASP (동일) | bandit(S) |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) | pre-commit (동일) |

## 자동 적용

```bash
cd /path/to/my-java-project
bash ~/.dev-standards/java-spring/bootstrap.sh
```

## 수동 적용 (단계별)

### 1. quality.gradle.kts 적용

```bash
cp ~/.dev-standards/java-spring/templates/quality.gradle.kts .
cp ~/.dev-standards/java-spring/templates/spotbugs-exclude.xml .
```

`quality.gradle.kts` 의 내용을 `build.gradle.kts` 에 **합친다** — `plugins { }` 블록과 `java { toolchain }` 은 기존 것과 하나로 합치고(이미 `sourceCompatibility` 나 다른 toolchain 이 있으면 지운다), 나머지는 그 아래에 붙인다.

> `apply(from = "quality.gradle.kts")` 로는 동작하지 않는다(Gradle 9.8.2 실측): 따로 불러오는 스크립트는 `plugins { }` 블록과
> `checkstyle { }` · `spotbugs { }` 같은 타입 안전 접근자를 쓸 수 없어 컴파일 오류가 난다.
> 이 합친 형태가 `./gradlew check` 를 통과하는 것은 `tests/enforcement-java-gradle.bats` 가 확인한다(JDK 25 · Gradle 9.8.2).
> **Groovy DSL 사용 시**: 같은 설정을 Groovy 문법으로 옮겨야 한다.

버전(2026-11-12 기준 최신 정식판 · 배포 7일 이상): JDK 25(LTS, toolchain) · checkstyle 14.4.0 · SpotBugs 4.10.5(플러그인 6.5.13) · JaCoCo 0.8.16 · OWASP dependency-check 13.0.0 · ArchUnit 1.5.1

### 2. checkstyle.xml 복사

```bash
cp ~/.dev-standards/java-spring/templates/checkstyle.xml .
```

수정 포인트:
- `CyclomaticComplexity.max: 15` -- 복잡도 한계 (Kotlin detekt와 동일)
- `MethodLength.max: 50` -- 함수 길이 제한
- `FileLength.max: 800` -- 파일 크기 제한
- `ParameterNumber.max: 6` -- 파라미터 수 제한

세는 방법(checkstyle 14.4.0 — `tests/enforcement-java.bats` 가 확인한 것만 적는다):
- 복잡도: `1 + 분기 수`. 테스트는 `if` 로 확인했고, 나머지는 checkstyle 기본 토큰(`for`·`while`·`do`·`case`·`catch`·`?:`·`&&`·`||`)이다. `switch` 자체와 `default` 는 세지 않는다
- 메서드 길이: 여는 `{` 가 있는 줄부터 닫는 `}` 까지. 그 앞의 시그니처 줄·어노테이션·Javadoc, 빈 줄, 주석만 있는 줄은 세지 않는다(`countEmpty=false`)
- 파일 길이: 빈 줄·주석을 포함한 실제 줄 수

> 주의: 막는 곳은 `./gradlew check` 와 pre-commit `checkstyle` 훅이다. Gradle checkstyle 플러그인은 소스셋마다 작업을 만들어
> `check` 에 붙이므로 테스트 소스(`checkstyleTest`)도 같은 한도를 받는다. 훅은 `checkstyleMain` 만 돌고, `gradlew` 가 없으면
> `[SKIP]` 을 찍고 통과한다 — Gradle Wrapper 를 커밋해 두어야 커밋 단계에서 실제로 막힌다.
> 검사가 꺼지는 경로(모두 fixture 로 확인): 경로에 `generated/` 가 들어간 파일은 통째로 빠진다(`BeforeExecutionExclusionFileFilter`),
> 소스의 `@SuppressWarnings("checkstyle:methodlength")` 나 `// CHECKSTYLE:OFF` 한 줄도 검사를 끈다(`SuppressWarningsHolder`·
> `SuppressionCommentFilter`). 생성 코드용 장치이니, 리뷰에서 이 표기와 손으로 쓴 `generated/` 파일을 찾아 이유를 남기게 한다.

### 3. 나머지 파일 복사

```bash
cp ~/.dev-standards/java-spring/templates/.editorconfig .
cp ~/.dev-standards/java-spring/templates/.pre-commit-config.yaml .
bash ~/.dev-standards/apply.sh --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash ~/.dev-standards/apply.sh --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 4. google-java-format 설치

```bash
# macOS
brew install google-java-format

# 또는 릴리스 다운로드
# https://github.com/google/google-java-format/releases
```

### 5. pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan --exclude-files 'build/.*' --exclude-files '.*\.jar' > .secrets.baseline
pre-commit install
pre-commit install --hook-type pre-push   # spotbugs는 push 시 실행
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `quality.gradle.kts` | Checkstyle + SpotBugs + JaCoCo + OWASP 통합 Gradle 설정 |
| `checkstyle.xml` | Google Java Style 기반 Checkstyle 규칙 (200줄+) |
| `spotbugs-exclude.xml` | SpotBugs 거짓 양성(false positive) 제외 필터 |
| `.editorconfig` | 에디터 공통 설정 (2 spaces, 100자) |
| `.pre-commit-config.yaml` | commit: google-java-format + checkstyle / push: spotbugs |

---

## 주요 Gradle 명령어

```bash
./gradlew qualityCheck    # checkstyle + spotbugs + test + jacoco 통합 검증
./gradlew qualityFix      # google-java-format 자동 수정 + spotbugs 검사
./gradlew checkstyleMain  # 스타일 검사만
./gradlew spotbugsMain    # 버그 탐지만
./gradlew test            # 테스트만
./gradlew jacocoTestReport              # 커버리지 리포트 (build/reports/jacoco/)
./gradlew jacocoTestCoverageVerification  # 80% 미만이면 빌드 실패
./gradlew dependencyCheckAnalyze        # 보안 취약점 (느림, CI 전용 권장)
./gradlew googleJavaFormat              # Java 소스 자동 포매팅
```

---

## 주요 위반 패턴 및 수정법

### 1. CyclomaticComplexity -- 순환 복잡도 15 초과

```java
// WRONG: 복잡한 분기가 함수 하나에 집중
public OrderResult processOrder(Order order) {
  if (order.isPriority()) {
    if (order.hasDiscount()) {
      if (order.getDiscount() > 30) {
        // ... 15+ 분기 ...
      }
    }
  }
}

// RIGHT: 책임 분리
public OrderResult processOrder(Order order) {
  var validated = validateOrder(order);
  var priced = applyPricing(validated);
  return fulfillOrder(priced);
}

private ValidatedOrder validateOrder(Order order) { /* ... */ }
private PricedOrder applyPricing(ValidatedOrder order) { /* ... */ }
private OrderResult fulfillOrder(PricedOrder order) { /* ... */ }
```

### 2. MethodLength -- 함수 50줄 초과

```java
// WRONG: 100줄짜리 메서드
public void importData(InputStream input) {
  // parse, validate, transform, save, notify... 100줄
}

// RIGHT: 단계별 분리 (각 메서드 <= 50줄)
public void importData(InputStream input) {
  var raw = parseInput(input);
  var validated = validateRecords(raw);
  var transformed = transformRecords(validated);
  saveRecords(transformed);
  notifyCompletion(transformed.size());
}
```

### 3. AvoidStarImport -- 와일드카드 import 금지

```java
// WRONG
import java.util.*;
import org.springframework.web.bind.annotation.*;

// RIGHT
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
```

### 4. MissingJavadocMethod -- public 메서드에 Javadoc 누락

```java
// WRONG
public User findById(Long id) {
  return userRepository.findById(id).orElseThrow();
}

// RIGHT
/**
 * Find user by ID.
 *
 * @param id user primary key
 * @return found user entity
 * @throws NoSuchElementException if user not found
 */
public User findById(Long id) {
  return userRepository.findById(id)
      .orElseThrow(() -> new NoSuchElementException("User not found: " + id));
}
```

### 5. StringLiteralEquality -- 문자열 == 비교

```java
// WRONG: reference equality
if (status == "ACTIVE") { ... }

// RIGHT: value equality
if ("ACTIVE".equals(status)) { ... }
// 또는 (null-safe, 더 명확)
if (Objects.equals(status, "ACTIVE")) { ... }
```

---

## Kotlin 템플릿과의 차이점

| 항목 | Java/Spring Boot | Kotlin/Spring Boot |
|------|-----------------|-------------------|
| **포매터** | google-java-format (외부 도구) | ktlint (Gradle 플러그인) |
| **정적 분석** | Checkstyle + SpotBugs (2개 도구) | detekt (단일 도구) |
| **스타일 기준** | Google Java Style (checkstyle.xml) | ktlint built-in + detekt.yml |
| **들여쓰기** | 2 spaces (Google Style) | 4 spaces (Kotlin 표준) |
| **줄 길이** | 100자 | 120자 |
| **Null 안전** | Optional + @Nullable 어노테이션 | 언어 내장 (?, ?:, ?.let) |
| **불변성** | record, final, Collections.unmodifiable | data class, val, List (불변) |
| **아키텍처 테스트** | ArchUnit onion (`ArchitectureTest.java`) | ArchUnit onion (`ArchitectureTest.kt`) |
| **복잡도 한계** | CyclomaticComplexity <= 15 (동일) | CyclomaticComplexMethod <= 15 (동일) |
| **함수 길이** | MethodLength <= 50 (동일) | LongMethod <= 50 (동일) |
| **파일 크기** | FileLength <= 800 | LargeClass <= 600 |

### Java만의 추가 검사

- **SpotBugs**: null dereference, 리소스 누수, 동시성 버그 등 바이트코드 수준 분석
- **Checkstyle NestedIfDepth**: 중첩 if 최대 3단계 (Kotlin은 when 사용)
- **ParameterNumber**: 파라미터 6개 초과 시 경고 (DTO/Builder 패턴 유도)

---

## Java 코딩 패턴 체크리스트

```
불변성
[ ] record 사용 (Java 16+, DTO/값 객체)
[ ] final 필드 우선 (가변 최소화)
[ ] Collections.unmodifiableList() / List.of() / List.copyOf()
[ ] Optional 반환 (null 대신)

타입 안전성
[ ] sealed class/interface (Java 17+, ADT 표현)
[ ] enum 적극 활용 (문자열 상수 대신)
[ ] @Nullable / @NonNull 어노테이션
[ ] Generic 타입 바운드 명시

설계
[ ] Interface 기반 DI
[ ] Constructor injection만 (필드 주입 금지)
[ ] Service -> Repository만 (계층 준수)
[ ] Builder 패턴 (6+ 파라미터)

품질
[ ] 순환 복잡도 <= 15 (Checkstyle CyclomaticComplexity)
[ ] 함수 <= 50줄 (Checkstyle MethodLength)
[ ] 파일 <= 800줄 (Checkstyle FileLength)
[ ] 매직 넘버 -> static final 상수
[ ] 모든 public API에 Javadoc

테스트
[ ] 단위: JUnit 5 + Mockito
[ ] 슬라이스: @WebMvcTest / @DataJpaTest (빠른 실행)
[ ] 통합: Testcontainers
[ ] 커버리지: JaCoCo >= 80%

보안
[ ] OWASP Dependency Check (CI)
[ ] SpotBugs 보안 규칙 통과
[ ] 하드코딩 시크릿 없음 (detect-secrets)
```

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음

pre-push 훅 `coverage-gate` 가 리포트를 만든 뒤 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 부른다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: `origin/main` 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

전체 80% 를 처음부터 강제하지 않는 이유: 커버리지가 낮은 기존 프로젝트는 모든 PR 이 막힌다. 대신 새로 쓰는 코드는 80% 를 지키고, 전체는 한 방향으로만 오른다.

| 항목 | 내용 |
|---|---|
| 리포트 | `./gradlew test jacocoTestReport` → `build/reports/jacoco/test/jacocoTestReport.xml` |
| 필요한 것 | `quality.gradle.kts` 의 JaCoCo XML 리포트(이미 켜져 있음) · uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage.bats` 가 lcov·JaCoCo 리포트로 바뀐 줄 80% 통과 · 79% 실패, ratchet 통과 · 실패를 확인한다.
> 언어 도구가 리포트를 만드는 부분은 그 테스트 범위 밖이다.
> 한계: 리포트에 아예 없는 파일(예: 어떤 테스트도 불러오지 않은 새 파일)은 분모에서 빠진다. 문서·테스트만 바꾼 변경은
> 측정할 줄이 없어 알림과 함께 통과한다. 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 하나도 맞지 않으면(경로 불일치) 실패한다. Java·Kotlin 소스 폴더가 다르면 `--src-roots "모듈/src/main/kotlin …"` 을 준다.

## 아키텍처 규칙 — ArchUnit onion

`quality.gradle.kts` 가 `archunit-junit5` 를 testImplementation 으로 넣고, bootstrap 이 `ArchitectureTest.java` 를
`src/test/java/architecture/` 로 복사한다(선택). 복사 후 파일의 `package` 와 `BASE_PACKAGE` 를 프로젝트에 맞게 바꾼다.

패키지 구조 — 의존은 바깥(adapter)에서 안쪽(domain)으로만 향한다:

| 패키지 (`BASE_PACKAGE` 아래) | 역할 | 쓸 수 있는 것 |
|---|---|---|
| `domain.model..` | 도메인 모델 | 없음 |
| `domain.service..` | 도메인 서비스 | domain.model |
| `application..` | 유스케이스 · 어댑터가 구현할 포트 인터페이스 | domain |
| `adapter.web..` · `adapter.persistence..` | 컨트롤러 · 리포지토리 | application · domain (어댑터끼리는 안 됨) |

- 규칙 8개: onion 구조 · `@Service`/`@Repository`/`@Controller` 위치 · 필드 주입 금지 · 패키지 순환 금지 · 이름 접미사
- **계층 하나라도 클래스가 없으면 onion 테스트가 실패한다**(`Layer 'domain service' is empty`) — 패키지 이름 오타를 잡기 위해서다. 쓰지 않는 계층(예: 도메인 서비스가 없는 작은 프로젝트)이 있으면 `onionArchitecture()` 뒤에 `.withOptionalLayers(true)` 를 붙인다. 그 계층 줄을 지우는 것으로는 안 된다(ArchUnit 이 빈 계층으로 본다 — 테스트로 확인). 이 옵션을 켜면 오타 검사도 함께 꺼진다
- 도메인이 어댑터를 쓰면 onion 규칙이 그 호출을 지목한다. 맨 위 패키지 단위 순환 규칙도 보통 함께 실패한다(어댑터 → application → domain 의존이 보통 있으므로)
- onion 규칙은 위 패키지들 사이의 의존만 본다 — 그 밖의 패키지(`config` 등)는 onion 이 검사하지 않는다. 단 순환 규칙은 `BASE_PACKAGE` 바로 아래 패키지를 모두(`config` 포함) 하나씩 묶어 순환을 본다
- **기존 프로젝트에 붙일 때(옵션 · 이 저장소 테스트로는 검증하지 않음)**: 위반이 이미 많으면 규칙을 `FreezingArchRule.freeze(...)` 로 감싸 지금의 위반을 기록해 두고 **새 위반만** 막는다. 기록 저장소는 기본으로 새로 만들지 않으므로 처음 한 번은 `src/test/resources/archunit.properties` 에 `freeze.store.default.allowStoreCreation=true` 를 둔다. 기록 파일(`archunit_store/`)은 커밋하고, 위반을 고칠 때마다 줄어든다. 새 프로젝트는 감싸지 않는다
- 검증: `tests/enforcement-archunit.bats` 가 이 템플릿을 실제 Gradle 프로젝트에서 돌린다(Kotlin·Java 각각: 정상 통과 · 도메인 → 어댑터 실패 · 빈 계층 실패 · 필드 주입 실패 · `@Repository`·`@Service`·`@RestController` 위치와 이름 위반 실패. Java 템플릿은 checkstyle 도 통과)

```java
// WRONG — domain.model 이 adapter.persistence 를 부른다
package com.example.domain.model;
import com.example.adapter.persistence.JdbcClock;
public record Order(long id) { public long stamp() { return JdbcClock.now(); } }

// RIGHT — 포트 인터페이스를 application 에 두고 어댑터가 구현한다
package com.example.application;
public interface ClockPort { long now(); }
```
