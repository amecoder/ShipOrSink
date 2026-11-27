# Kotlin / Spring Boot 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Python 대응 |
|------|------|-------------|
| **detekt** | 정적 분석, 복잡도, 네이밍 | ruff |
| **ktlint** | 포매터 | ruff format |
| **JaCoCo** | 커버리지 (≥ 80%) | pytest-cov |
| **ArchUnit** | Onion 아키텍처 규칙 강제 (도메인 → 어댑터 의존 금지) | — (Python엔 없음) |
| **OWASP Dependency Check** | 취약점 스캔 | bandit(S) |
| **MockK + Kotest** | Kotlin 표준 테스트 스택 | pytest + unittest.mock |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) |

## 자동 적용

```bash
cd /path/to/my-kotlin-project
bash "$SOS_STANDARDS/kotlin-spring/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. quality.gradle.kts 적용

```bash
cp "$SOS_STANDARDS/kotlin-spring/templates/quality.gradle.kts" .
```

`quality.gradle.kts` 의 내용을 `build.gradle.kts` 에 **합친다** — `plugins { }` 블록과 `kotlin { jvmToolchain }` 은 기존 것과 하나로 합치고,
나머지는 그 아래에 붙인다. 플러그인 버전은 아래 2번의 버전 카탈로그(`alias(libs.plugins…)`)에서 온다.

> `apply(from = "quality.gradle.kts")` 로는 동작하지 않는다(Gradle 9.8.2 실측 — 따로 불러오는 스크립트는 `plugins { }` 와
> `detekt { }` 같은 타입 안전 접근자를 쓸 수 없다). 합친 형태가 `./gradlew check` 를 통과하는 것은 `tests/enforcement-kotlin-gradle.bats` 가 확인한다.

버전(2026-11-12 기준 최신 정식판 · 배포 7일 이상 — detekt 만 예외): JDK 25(LTS) · detekt 2.0.0-alpha.6 · ktlint 1.8.0(플러그인 14.2.0) ·
JaCoCo 0.8.16 · OWASP 13.0.0 · ArchUnit 1.5.1 · MockK 1.14.11 · Kotest 6.2.6 · Testcontainers 2.0.5(모듈 이름이 `testcontainers-*` 로 바뀜) · springmockk 5.0.1

### 2. 버전 카탈로그 (`gradle/libs.versions.toml`)

`libs-quality.versions.toml` 내용을 기존 `libs.versions.toml`에 병합:

```bash
cat "$SOS_STANDARDS/kotlin-spring/templates/libs-quality.versions.toml"
```

### 3. detekt.yml 복사

```bash
cp "$SOS_STANDARDS/kotlin-spring/templates/detekt.yml" .
```

수정 포인트:
- `LongMethod.allowedLines: 50` — 함수 길이 제한 (50줄까지 통과)
- `CyclomaticComplexMethod.allowedComplexity: 15` — 복잡도 (15까지 통과 — Python mccabe 와 같은 허용치)
- `LargeClass.allowedLines: 600` — 클래스 크기 제한 (600줄까지 통과)

> **detekt 2.0 은 허용치를 그대로 적는다.** `allowed…` 값을 **넘으면** 보고한다(`tests/enforcement-kotlin.bats` 가 2.0.0-alpha.6 으로
> 15·50 통과 · 16·51 실패를 확인). 1.23 의 `threshold` 는 "같거나 크면" 보고해서 허용치 + 1 을 적었다 — 1.x 설정을 옮길 때 1 씩 뺀다.
> 2.0 에서 바뀐 이름(1.23 → 2.0): `threshold` → `allowedComplexity`·`allowedLines`·`allowedDepth`·`allowedDefinitions`·`allowedOperations` ·
> `functionThreshold`·`constructorThreshold` → `allowedFunctionParameters`·`allowedConstructorParameters` · `thresholdIn*` → `allowedFunctionsPer*` ·
> `UnusedImports` → `UnusedImport` · `RedundantVisibilityModifierRule` → `RedundantVisibilityModifier` · `SpacingBetweenPackageAndImports` → `SpacingAfterPackageAndImports` ·
> `UnnecessaryAbstractClass` → `AbstractClassCanBeConcreteClass` + `AbstractClassCanBeInterface` · `CommentOverPrivate*` → `DocumentationOverPrivate*` ·
> `EmptyKtFile` → `EmptyKotlinFile`. 없어진 것: `build:`(maxIssues — error 심각도 위반이 있으면 실패) · `PreferToOverPairSyntax`

세는 방법(fixture 로 확인한 것만): 복잡도는 `1 + 분기 수`(테스트는 `if` 로 확인, `ignoreSimpleWhenEntries: true`).
함수 길이는 여는 `{` 줄부터 닫는 `}` 까지이고, 그 앞의 시그니처 줄·빈 줄·주석만 있는 줄은 세지 않는다.
파일 길이는 detekt 에 규칙이 없어 pre-commit `file-size-limit` 훅이 실제 줄 수로 600 을 막는다. 훅 패턴이 `^src/main/` 이라
멀티모듈(`app/src/main/…`)이면 `files:` 를 모듈 경로에 맞게 고친다.

> 주의
> - `config.validation: true` 라 detekt 가 모르는 규칙·옵션 이름이 하나라도 있으면 분석 없이 실패한다(exit 3). 2026-11-06 전 템플릿은
>   없는 이름 5개 때문에 detekt 가 한 번도 돌지 못했다 — 버전을 올릴 때 `detekt --generate-config` 결과와 이름을 대조한다.
>   그때 바꾼 것: `ConstantNaming` → `TopLevelPropertyNaming` + `ObjectPropertyNaming` · `PrintExceptionInCatchBlock` → `PrintStackTrace` ·
>   `allowNonStandardGroupings` → `allowNonStandardGrouping`. 지운 것: `NPathComplexity`(1.23 에 없음) · `MissingWhenCase`(폐기 — 컴파일러가 검사) ·
>   `SpreadOperator.excludedFunctions`(옵션 없음 — `arrayOf`·`listOf` 안의 spread 도 이제 보고 대상, 단 이 규칙은 타입 해석이 필요해 `detekt` 태스크에선 거의 동작하지 않는다)
> - **detekt 는 2.0.0-alpha.6(프리릴리스)을 쓴다**(사용자 결정 2026-11-12 — 이 저장소에서 유일한 프리릴리스 예외). 정식 최신 1.23.8 은 Gradle 을 JDK 25 로 돌리면 `25.0.5` 로 실패하고(1.23.7 은 CLI 도 실패), 분석 jvmTarget 도 22 까지다. 2.0 은 공식 호환표상 JDK 25 · Gradle 9 를 시험한 유일한 계열이다. 플러그인 id 가 `dev.detekt` 로 바뀌었다. 정식 2.0.0 이 나오면 바로 옮긴다
> - JDK 는 25(최신 LTS) — `kotlin { jvmToolchain(25) }` · ci-kotlin.yml `JAVA_VERSION: "25"`
> - 소스의 `@Suppress("CyclomaticComplexMethod")` · `@Suppress("LongMethod")` 한 줄로 그 함수의 검사가 꺼진다 — 리뷰에서 찾아 이유를 남기게 한다

### 4. 나머지 파일 복사

```bash
cp "$SOS_STANDARDS/kotlin-spring/templates/.editorconfig" .
cp "$SOS_STANDARDS/kotlin-spring/templates/.pre-commit-config.yaml" .
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 5. ArchUnit 테스트 복사

```bash
mkdir -p src/test/kotlin/com/example/architecture
cp "$SOS_STANDARDS/kotlin-spring/templates/ArchitectureTest.kt" \
   src/test/kotlin/com/example/architecture/
# BASE_PACKAGE를 실제 패키지명으로 변경
```

의존성은 버전 카탈로그(`libs-quality.versions.toml` 의 `archunit`)로 넣는다:

```kotlin
dependencies {
    testImplementation(libs.archunit.junit5)
}
```

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

### 6. pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan --exclude-files 'build/.*' --exclude-files '.*\.jar' > .secrets.baseline
pre-commit install
pre-commit install --hook-type pre-push   # detekt는 push 시 실행
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `quality.gradle.kts` | detekt + ktlint + JaCoCo + OWASP 통합 Gradle 설정 |
| `libs-quality.versions.toml` | 품질 도구 버전 카탈로그 (기존에 병합) |
| `detekt.yml` | detekt 규칙 설정 (300줄+, 빅테크 기준) |
| `.editorconfig` | 에디터 공통 설정 (indent, charset 등) |
| `.pre-commit-config.yaml` | commit: ktlint / push: detekt |
| `ArchitectureTest.kt` | ArchUnit Onion 아키텍처 규칙 테스트 |

---

## 주요 Gradle 명령어

```bash
./gradlew qualityCheck    # ktlint + detekt + test + jacoco 통합 검증
./gradlew qualityFix      # ktlint 자동 수정 + detekt 검사
./gradlew ktlintFormat    # 포매팅만
./gradlew detektMain detektTest   # 정적 분석(타입 해석 포함 — `./gradlew detekt` 는 타입이 필요한 규칙 약 40개를 건너뛴다)
./gradlew test            # 테스트만
./gradlew jacocoTestReport              # 커버리지 리포트 (build/reports/jacoco/)
./gradlew jacocoTestCoverageVerification  # 80% 미만이면 빌드 실패
./gradlew dependencyCheckAnalyze        # 보안 취약점 (느림, CI 전용 권장)
```

---

## detekt 주요 위반 패턴 및 수정법

### LongMethod — 함수 50줄 초과

```kotlin
// WRONG: 50줄 넘는 함수
fun processOrder(...) {
    // 100줄...
}

// RIGHT: 책임 분리
fun processOrder(order: Order): OrderResult {
    val validated = validateOrder(order)
    val calculated = calculatePrice(validated)
    return fulfillOrder(calculated)
}
```

### MagicNumber — 매직 넘버

```kotlin
// WRONG
if (age < 18) throw IllegalArgumentException()
if (score > 0.7) return Recommendation.HIGH

// RIGHT
companion object {
    private const val MIN_ADULT_AGE = 18
    private const val HIGH_CONFIDENCE_THRESHOLD = 0.7
}
```

### TooGenericExceptionCaught — 너무 포괄적인 예외

```kotlin
// WRONG
try {
    process()
} catch (e: Exception) { log(e) }

// RIGHT
try {
    process()
} catch (e: IllegalArgumentException) {
    log.warn("Invalid input: ${e.message}")
} catch (e: IOException) {
    log.error("IO error during processing", e)
}
```

### LateinitUsage — lateinit 남용 (Spring DI 제외)

```kotlin
// WRONG (non-DI context)
lateinit var service: UserService

// RIGHT
class UserController(
    private val userService: UserService   // constructor injection
)
```

### DoubleMutabilityForCollection — 이중 가변성

```kotlin
// WRONG: var + MutableList 중복
var items: MutableList<Item> = mutableListOf()

// RIGHT: val + MutableList (또는 val + immutable)
val items: MutableList<Item> = mutableListOf()
// 또는
val items: List<Item> = listOf()
```

### Onion (ArchUnit) — 도메인이 어댑터를 쓰면 실패

```kotlin
// WRONG — domain.model 이 adapter.persistence 를 부른다
package com.example.domain.model
import com.example.adapter.persistence.JdbcClock
data class Order(val id: Long) { fun stamp() = JdbcClock.now() }

// RIGHT — 도메인(또는 application)에 포트 인터페이스를 두고 어댑터가 구현한다
package com.example.application
interface ClockPort { fun now(): Long }
```

### NoFieldInjection (ArchUnit) — 필드 주입 금지

```kotlin
// WRONG
@Autowired
lateinit var userService: UserService

// RIGHT
@Service
class UserController(
    private val userService: UserService   // constructor injection
)
```

---

## Kotlin 코딩 패턴 체크리스트

```
불변성
□ data class + copy() (Python frozen dataclass 대응)
□ val 우선 (var는 꼭 필요할 때만)
□ List/Map/Set (불변) 기본, 가변이 필요하면 MutableList

타입 안전성
□ Null 안전: ?, ?:, ?.let, requireNotNull
□ value class로 도메인 원시타입 래핑
   (e.g., @JvmInline value class ProductCode(val value: String))
□ sealed class / sealed interface 로 ADT 표현

설계
□ Interface 기반 DI (Python Protocol 대응)
□ Constructor injection만 (필드 주입 금지)
□ 의존은 adapter → application → domain 방향만 (ArchUnit onion 으로 검증)

품질
□ McCabe 복잡도 ≤ 15 (detekt CyclomaticComplexMethod)
□ 함수 ≤ 50줄 (detekt LongMethod)
□ 클래스 ≤ 600줄 (detekt LargeClass)
□ 매직 넘버 → companion object const val
□ 모든 public API에 KDoc

테스트
□ 단위: Kotest + MockK
□ 슬라이스: @WebMvcTest / @DataJpaTest (빠른 실행)
□ 통합: Testcontainers
□ 커버리지: JaCoCo ≥ 80%
□ 아키텍처: ArchUnit (onion 규칙)
```

---

## Kotlin Multiplatform (KMP)

Kotlin Multiplatform은 하나의 Kotlin 코드베이스에서 Android, iOS, Web, Desktop, Server 등 여러 플랫폼을 대상으로 비즈니스 로직을 공유하는 기술이다. JetBrains가 공식 지원하며 2023년 Stable로 전환되었다.

### KMP 개요

| 항목 | 설명 |
|------|------|
| **핵심 가치** | 플랫폼별 중복 로직 제거, 단일 코드베이스로 유지보수 비용 절감 |
| **공유 가능 영역** | 네트워크, 데이터 모델, 비즈니스 로직, 유틸리티 |
| **플랫폼 고유 영역** | UI, 센서/카메라, 플랫폼 SDK 호출 |
| **빌드 도구** | Gradle + Kotlin Multiplatform 플러그인 |

### 공유 모듈 구조

```
shared/
├── src/
│   ├── commonMain/       # Platform-independent code
│   │   └── kotlin/
│   │       ├── model/    # Data models (data class, sealed class)
│   │       ├── domain/   # Business logic
│   │       └── util/     # Utility functions
│   ├── commonTest/       # Shared tests
│   │   └── kotlin/
│   ├── androidMain/      # Android-specific implementations
│   │   └── kotlin/
│   ├── iosMain/          # iOS-specific implementations
│   │   └── kotlin/
│   └── jvmMain/          # JVM (Server) specific implementations
│       └── kotlin/
└── build.gradle.kts
```

### expect/actual 패턴

`expect`/`actual` 키워드를 사용하여 플랫폼별 구현을 분리한다. `commonMain`에서 인터페이스를 선언하고, 각 플랫폼 소스셋에서 실제 구현을 제공한다.

```kotlin
// commonMain -- platform contract
expect fun platformName(): String

expect class SecureStorage {
    fun save(key: String, value: String)
    fun load(key: String): String?
}
```

```kotlin
// androidMain -- Android implementation
actual fun platformName(): String = "Android ${Build.VERSION.SDK_INT}"

actual class SecureStorage {
    private val prefs = EncryptedSharedPreferences.create(/*...*/)

    actual fun save(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }

    actual fun load(key: String): String? =
        prefs.getString(key, null)
}
```

```kotlin
// iosMain -- iOS implementation
actual fun platformName(): String = "iOS ${UIDevice.currentDevice.systemVersion}"

actual class SecureStorage {
    actual fun save(key: String, value: String) {
        NSUserDefaults.standardUserDefaults.setObject(value, forKey = key)
    }

    actual fun load(key: String): String? =
        NSUserDefaults.standardUserDefaults.stringForKey(key)
}
```

### KMP 품질 관리 포인트

- `commonMain` 코드에도 동일한 detekt/ktlint 규칙을 적용한다
- `commonTest`에서 공유 로직의 단위 테스트를 작성하고, 플랫폼별 테스트는 `androidTest`/`iosTest`에서 보완한다
- `expect`/`actual` 선언은 최소화하고, 가능하면 인터페이스 + DI 패턴으로 대체하는 것이 테스트 용이성에 유리하다

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
