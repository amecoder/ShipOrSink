# Kotlin Multiplatform (KMP) 가이드

> **최종 수정**: 2026-05-01
> **대상**: Android / iOS / Web / Desktop / Server 멀티 타겟 Kotlin 프로젝트
> **목적**: KMP의 모듈 구조, 품질 도구 적용, 테스트 전략, 배포 파이프라인 표준화

KMP는 같은 비즈니스 로직을 여러 플랫폼에서 공유하면서, 플랫폼별 UI는 네이티브로 유지하는 패턴이다. JetBrains가 2023년 안정화(`kotlin-multiplatform` Gradle plugin)했고, 2024-2025년 모바일/서버 채택이 빠르게 늘었다.

---

## 1. 채택 결정 기준

KMP는 만능이 아니다. 다음 조건이 **두 개 이상** 충족될 때 가치가 크다.

| 조건 | 설명 |
|------|------|
| 다중 플랫폼 동시 출시 | iOS + Android 같은 비즈니스 로직 |
| 비즈니스 로직 비중 | UI보다 도메인/네트워킹/캐싱이 큼 (50% 이상) |
| 팀 구성 | Kotlin 경험자 2명 이상 + iOS 협업 가능 |
| 변경 빈도 | 동일 로직을 양쪽 플랫폼에서 자주 수정해야 함 |
| 출시 일관성 | 플랫폼 간 동작 차이를 최소화해야 함 |

**채택하지 말아야 할 경우**:
- UI 중심 앱 (KMP는 UI를 공유하지 않음. UI도 공유하려면 Compose Multiplatform — 별도 결정)
- iOS 전담 팀이 Swift만 다룰 의지가 있음
- 출시 1회성 / 프로토타입 (KMP 학습 비용이 더 큼)

---

## 2. 모듈 구조 표준

```
my-kmp-project/
├── build.gradle.kts                  # 루트 빌드 (버전 카탈로그 + Detekt + KtLint)
├── gradle/
│   └── libs.versions.toml            # 버전 카탈로그
├── shared/
│   ├── build.gradle.kts              # KMP 모듈 (multiplatform plugin)
│   └── src/
│       ├── commonMain/kotlin/        # 공통 비즈니스 로직 (모든 타겟)
│       ├── commonTest/kotlin/        # 공통 테스트 (kotlin.test)
│       ├── androidMain/kotlin/       # Android 전용 actual
│       ├── iosMain/kotlin/           # iOS 전용 actual (iosX64 + iosArm64 + iosSimulatorArm64)
│       ├── jvmMain/kotlin/           # JVM (서버 / 데스크톱)
│       └── jsMain/kotlin/            # JavaScript (Web)
├── androidApp/                       # Android UI (Jetpack Compose)
├── iosApp/                           # iOS UI (SwiftUI)
└── server/                           # Ktor / Spring 서버 (선택)
```

### 핵심 원칙
- `commonMain`이 **계약(interface, expect)** 의 단일 출처
- 플랫폼별 구현은 `actual` 키워드로
- 의존성은 `libs.versions.toml`에서 단일 관리

---

## 3. expect/actual vs Interface

KMP의 두 가지 추상화 메커니즘:

| 패턴 | 사용 시점 | 예시 |
|------|-----------|------|
| **expect/actual** | 플랫폼 API 직접 매핑이 필요할 때 | 시계, 파일 IO, 암호화 |
| **interface + DI** | 비즈니스 로직 인터페이스 | Repository, UseCase, Logger |

### expect/actual 예시

```kotlin
// commonMain/kotlin/Platform.kt
expect class Platform() {
    val name: String
}

expect fun currentTimeMillis(): Long

// androidMain/kotlin/Platform.android.kt
actual class Platform actual constructor() {
    actual val name: String = "Android ${android.os.Build.VERSION.SDK_INT}"
}

actual fun currentTimeMillis(): Long = System.currentTimeMillis()

// iosMain/kotlin/Platform.ios.kt
import platform.UIKit.UIDevice
import platform.Foundation.NSDate
import platform.Foundation.timeIntervalSince1970

actual class Platform actual constructor() {
    actual val name: String = "${UIDevice.currentDevice.systemName()} ${UIDevice.currentDevice.systemVersion}"
}

actual fun currentTimeMillis(): Long = (NSDate().timeIntervalSince1970 * 1000).toLong()
```

### Interface + DI 예시 (선호)

```kotlin
// commonMain
interface UserRepository {
    suspend fun getUser(id: String): User
}

class GetUserUseCase(private val repo: UserRepository) {
    suspend operator fun invoke(id: String): User = repo.getUser(id)
}

// androidMain — Koin / Hilt로 주입
single<UserRepository> { AndroidUserRepository(get(), get()) }

// iosMain — Swift에서 호출
let useCase = GetUserUseCase(repo: IosUserRepository())
```

**원칙**: expect/actual은 최소화하고, **interface + DI**를 우선 사용한다. expect/actual은 컴파일러 검증이 강력하지만 변경 비용이 크다.

---

## 4. 품질 도구 적용

### 4.1 Detekt + KtLint (kotlin-spring와 동일)

```kotlin
// build.gradle.kts (root)
plugins {
    id("dev.detekt") version "2.0.0-alpha.6"
    id("org.jlleitschuh.gradle.ktlint") version "14.2.0"
}

allprojects {
    apply(plugin = "dev.detekt")
    apply(plugin = "org.jlleitschuh.gradle.ktlint")

    detekt {
        config.setFrom(rootProject.file("config/detekt/detekt.yml"))
        buildUponDefaultConfig = true
        allRules = false
    }

    ktlint {
        version.set("1.4.0")
        android.set(false)
    }
}
```

`config/detekt/detekt.yml`은 [`kotlin-spring/templates/detekt.yml`](../../kotlin-spring/templates/detekt.yml)을 그대로 재사용한다. KMP 특화 규칙 추가 권장:

```yaml
# detekt.yml — KMP 보강
naming:
  PackageNaming:
    packagePattern: "^[a-z]+(\\.[a-z][a-z0-9]*)*$"

style:
  ForbiddenComment:
    values: ["TODO:", "FIXME:", "STOPSHIP:", "HACK:"]
  MaxLineLength:
    maxLineLength: 120

complexity:
  TooManyFunctions:
    thresholdInClasses: 15  # KMP shared 모듈은 더 엄격
```

### 4.2 테스트 전략

```kotlin
// commonTest — 모든 플랫폼에서 실행되는 테스트
class UserUseCaseTest {
    @Test
    fun `should fetch user`() = runTest {
        val repo = FakeUserRepository()
        val useCase = GetUserUseCase(repo)
        val user = useCase("123")
        assertEquals("Alice", user.name)
    }
}

// androidTest — Android 전용 (Robolectric / Espresso)
class AndroidUserRepositoryTest { /* ... */ }

// iosTest — iOS 전용 (XCTest)
class IosUserRepositoryTest { /* ... */ }
```

**원칙**:
- 비즈니스 로직 테스트는 `commonTest`에만 (각 플랫폼에서 실행됨)
- `kotlin.test` + `kotlinx-coroutines-test` 조합
- `MockK`는 JVM 전용 → KMP에서는 [`mockative`](https://github.com/mockative/mockative) 또는 fake 객체 사용

### 4.3 커버리지 (Kover)

JaCoCo는 JVM 전용이라 KMP에서는 [`Kover`](https://github.com/Kotlin/kotlinx-kover)(JetBrains 공식)를 사용한다.

```kotlin
// build.gradle.kts (shared)
plugins {
    id("org.jetbrains.kotlinx.kover") version "0.9.1"
}

kover {
    reports {
        verify {
            rule {
                minBound(80)  // 80% 커버리지
            }
        }
    }
}
```

```bash
./gradlew :shared:koverHtmlReport
./gradlew :shared:koverVerify   # 80% 미만 시 실패
```

---

## 5. iOS Framework 빌드 + 배포

### 5.1 XCFramework 생성

```kotlin
// shared/build.gradle.kts
kotlin {
    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64(),
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }
}

// XCFramework 작업 추가
tasks.register("assembleSharedXCFramework", XCFrameworkTask::class) {
    baseName = "Shared"
    val xcf = XCFramework(baseName)
    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach { target ->
        xcf.add(target.binaries.framework)
    }
}
```

### 5.2 SPM (Swift Package Manager) 통합

```bash
./gradlew :shared:assembleSharedXCFramework
# 결과: shared/build/XCFrameworks/release/Shared.xcframework
```

iOS 팀에 전달하는 방식 3가지:
1. **Direct path**: 같은 monorepo면 iosApp이 직접 참조
2. **SPM**: `Package.swift`에 `binaryTarget` 등록 + GitHub Releases에 zip 업로드
3. **CocoaPods**: `cocoapods` Gradle plugin (deprecated 추세, SPM 권장)

### 5.3 CI/CD (GitHub Actions)

```yaml
# .github/workflows/kmp-ci.yml
name: KMP CI
on: [push, pull_request]

jobs:
  jvm:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      - name: Lint + Test (JVM)
        run: |
          ./gradlew detekt ktlintCheck
          ./gradlew :shared:jvmTest
          ./gradlew :shared:koverVerify

  ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      - name: iOS test (Simulator)
        run: ./gradlew :shared:iosSimulatorArm64Test

  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
      - name: Android test
        run: ./gradlew :shared:testDebugUnitTest

  release-xcframework:
    needs: [jvm, ios, android]
    if: github.ref == 'refs/heads/main'
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: ./gradlew :shared:assembleSharedXCFramework
      - uses: actions/upload-artifact@v4
        with:
          name: Shared.xcframework
          path: shared/build/XCFrameworks/release/Shared.xcframework
```

---

## 6. Coroutines / Flow의 iOS 호환성

iOS(Swift)에서 Kotlin `suspend` 함수와 `Flow`를 사용하려면 변환이 필요하다.

### 6.1 suspend → async/await (Kotlin 1.9.20+)

Kotlin 1.9.20+ 의 새로운 Native 메모리 모델은 자동으로 `async/await` 호환을 제공한다.

```swift
// Swift
let user = try await GetUserUseCase(repo: repo).invoke(id: "123")
```

### 6.2 Flow → AsyncSequence

`Flow`는 직접 노출되지 않으므로 [`SKIE`](https://skie.touchlab.co/) 또는 KMP-NativeCoroutines 같은 라이브러리로 변환한다.

```kotlin
// commonMain
class UserStream {
    fun observe(): Flow<User> = flow { /* ... */ }
}
```

```swift
// Swift (SKIE 적용 시)
for try await user in stream.observe() {
    print(user)
}
```

### 6.3 권장: SKIE 적용

```kotlin
plugins {
    id("co.touchlab.skie") version "0.10.1"
}
```

SKIE가 Flow / sealed class / suspend 함수를 Swift에서 자연스럽게 쓸 수 있도록 변환한다.

---

## 7. 의존성 선택 가이드

| 카테고리 | KMP 호환 라이브러리 |
|----------|---------------------|
| **HTTP** | Ktor Client (KMP 공식) |
| **JSON** | kotlinx.serialization |
| **DB** | SQLDelight (멀티플랫폼 SQL) |
| **DI** | Koin (KMP 지원), Kodein |
| **Logging** | Napier, Kermit |
| **Date/Time** | kotlinx-datetime |
| **Image** | Coil 3 (KMP 지원, 2024 출시) |
| **Settings** | multiplatform-settings (Russell Wolf) |

**선택 기준**:
- KMP 공식 (`kotlinx.*`) > JetBrains > Touchlab > 기타
- 활성도 (최근 6개월 내 릴리스)
- iOS Swift 호환성 검증 (특히 Flow / suspend)

---

## 8. 안티패턴 (즉시 제거)

| 안티패턴 | 문제 | 대안 |
|----------|------|------|
| `commonMain`에 Android API 사용 | KMP 빌드 깨짐 | `expect/actual`로 분리 |
| `expect class`를 무분별하게 사용 | 변경 비용 폭증 | interface + DI로 대체 |
| Flow를 Swift에 그대로 노출 | iOS 사용 불가 | SKIE / KMP-NativeCoroutines |
| 플랫폼별 동작 차이를 commonMain에서 분기 | KMP의 의미 상실 | `expect/actual`로 명시 분리 |
| MockK를 commonTest에서 사용 | JVM 전용 | mockative 또는 fake 객체 |
| 모든 모듈을 multiplatform으로 | 빌드 시간 폭증 | UI 모듈은 플랫폼 전용으로 |
| 한 사람만 KMP 빌드 가능 | 팀 의존성 | onboarding 문서 + CI 강제 |

---

## 9. 도입 체크리스트

### 도입 전 결정 사항
- [ ] 채택 기준 (섹션 1) 2개 이상 충족 검증
- [ ] iOS 협업 가능 (Swift 빌드 / 배포 권한)
- [ ] CI에 macOS runner 사용 가능 (GitHub Actions `macos-14`)
- [ ] 팀 Kotlin 경험자 2명 이상

### 초기 셋업
- [ ] Gradle 8.10+ + Kotlin 2.1.0+
- [ ] `libs.versions.toml`에 KMP 버전 카탈로그
- [ ] Detekt + KtLint + Kover (JaCoCo 대신) 적용
- [ ] `commonMain` / `androidMain` / `iosMain` 표준 구조
- [ ] CI에서 JVM + iOS Simulator + Android 테스트 모두 실행

### 코드 표준
- [ ] expect/actual은 플랫폼 API 직접 매핑만
- [ ] 비즈니스 로직은 interface + DI
- [ ] Flow는 SKIE로 Swift 노출
- [ ] 모든 commonMain 코드에 commonTest 작성
- [ ] Kover 80% 커버리지

### 운영
- [ ] XCFramework 자동 빌드 (CI)
- [ ] SPM 또는 직접 경로로 iOS 통합
- [ ] 의존성 업데이트 시 4 플랫폼 동시 빌드 검증
- [ ] iOS 빌드 가능한 인원이 팀에 2명 이상

---

## 참고 자료

- [Kotlin Multiplatform 공식 문서](https://kotlinlang.org/docs/multiplatform.html)
- [Touchlab — KMP 모범 사례](https://touchlab.co/)
- [SKIE — Swift/KMP 호환성](https://skie.touchlab.co/)
- [JetBrains Compose Multiplatform](https://www.jetbrains.com/lp/compose-multiplatform/) — UI 공유 시 검토
- [SQLDelight](https://github.com/sqldelight/sqldelight)
- [Koin Multiplatform](https://insert-koin.io/docs/setup/koin#kotlin-multiplatform-setup)
