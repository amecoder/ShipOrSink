# Swift 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Kotlin 대응 | TypeScript 대응 |
|------|------|-------------|-----------------|
| **SwiftLint** | 정적 분석, 복잡도, 네이밍 | detekt | ESLint |
| **SwiftFormat** | 코드 포매팅 | ktlint | Prettier |
| **Periphery** | 데드코드 탐지 | detekt UnusedPrivateMember | ESLint no-unused |
| **swift test** | 단위/통합 테스트 + 커버리지 (>= 80%) | JaCoCo | Vitest |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) | Husky |
| **detect-secrets** | 시크릿 탐지 | detect-secrets (동일) | detect-secrets (동일) |

## 자동 적용

```bash
cd /path/to/my-swift-project
bash "$SOS_STANDARDS/swift/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. SwiftLint 설정 복사

```bash
cp "$SOS_STANDARDS/swift/templates/.swiftlint.yml" .
```

수정 포인트:
- `cyclomatic_complexity: 14` — 복잡도 제한 (SwiftLint 는 `if`·`guard`·`for`·`while`·`catch` 를 1 을 더하지 않고 센다 — 이 분기들에 대해서는 "1 + 분기 ≤ 15" 와 같다.
  `switch`/`case`·`&&`·`||`·`?:` 는 세지 않아 그런 함수는 일반 정의보다 느슨하게 잰다)
- `function_body_length: 50` — 함수 길이 제한 (중괄호 안, 주석·빈 줄 제외)
- `file_length: 800` — 파일 크기 제한 (주석·빈 줄 제외). 물리 줄 800 은 pre-commit `file-size-limit` 훅이 막는다

> **warning 과 error 를 같은 숫자로 둔다.** pre-commit 훅은 `swiftlint lint --strict` 라 warning 도 실패다 — 실제 한도는 warning 숫자다.
> 2026-11-06 전 템플릿은 warning 10 · 40 · 600 / error 15 · 50 · 800 이라, 표의 15 · 50 · 800 이 아니라 **10 · 40 · 600** 에서 막혔다
> (`tests/enforcement-swift.bats` 로 확인). `.swiftlint.yml` 의 **모든 규칙**이 같은 이유로 warning 숫자가 한도다
> (`type_body_length` 400 · `line_length` 120 · `closure_body_length` · `function_parameter_count` · `nesting` 등).
>
> - SwiftLint 의 복잡도는 `if`·`guard`·`for`·`while` 같은 분기만 센다. `?:`·`&&`·`||` 는 세지 않고, `ignores_case_statements: true` 라 `case` 도 뺀다
> - 리눅스에서 SwiftLint 는 Swift 툴체인의 SourceKit 이 필요하다(`LINUX_SOURCEKIT_LIB_PATH=<swift>/usr/lib`) — 없으면 시작하자마자 멈춘다
> - 소스 주석으로 검사가 꺼진다(재현함): 선언 줄 끝의 `// swiftlint:disable:this <규칙>`, `// swiftlint:disable <규칙>` … `// swiftlint:enable <규칙>` 쌍,
>   파일 첫 줄의 `// swiftlint:disable file_length`(이 규칙은 `blanket_disable_command` 의 허용 목록에 있다 — 물리 줄은 `file-size-limit` 훅이 막는다).
>   리뷰에서 `swiftlint:disable` 을 찾아 이유를 남기게 한다
> - 커버리지 80% 를 막는 훅은 아직 없다 — `swift test --enable-code-coverage` 는 리포트만 만든다(로드맵 A7)
- `included` — 프로젝트 소스 경로에 맞게 수정

### 2. SwiftFormat 설정 복사

```bash
cp "$SOS_STANDARDS/swift/templates/.swiftformat" .
```

수정 포인트:
- `--swiftversion` — 프로젝트 Swift 버전에 맞게 수정
- `--exclude` — 제외할 경로 추가

### 3. pre-commit 설정 복사

```bash
cp "$SOS_STANDARDS/swift/templates/.pre-commit-config.yaml" .
pip install pre-commit detect-secrets
pre-commit install
```

### 4. Claude Code 훅 설정

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

> `permissions.allow` 목록을 프로젝트에 맞게 수정하세요.

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `.swiftlint.yml` | SwiftLint strict 설정 (force_unwrapping 금지, 복잡도 15 — SwiftLint 값 14 등) |
| `.swiftformat` | SwiftFormat 설정 (indent 4, wrapArguments beforeFirst) |
| `.pre-commit-config.yaml` | swiftformat + swiftlint + detect-secrets |

---

## 주요 명령어

```bash
# SwiftLint
swiftlint lint                         # 정적 분석
swiftlint lint --strict                # 경고도 에러로 취급
swiftlint lint --fix                   # 자동 수정
swiftlint analyze                      # 심층 분석 (컴파일 필요)

# SwiftFormat
swiftformat .                          # 포매팅
swiftformat --lint .                   # 포매팅 검사 (CI)

# Periphery (데드코드)
periphery scan                         # 미사용 코드 탐지
periphery scan --strict                # 엄격 모드

# 테스트
swift test                             # 테스트 실행
swift test --enable-code-coverage      # 커버리지 포함
xcodebuild test -scheme MyApp -enableCodeCoverage YES  # Xcode 프로젝트
```

---

## SwiftLint 주요 위반 패턴 및 수정법

### 1. `force_unwrapping` — 강제 언래핑 금지

```swift
// WRONG: 런타임 크래시 위험
let name = user.name!
let value = dictionary["key"]!

// RIGHT: guard let 사용
guard let name = user.name else {
    return
}

// RIGHT: if let 사용
if let value = dictionary["key"] {
    process(value)
}

// RIGHT: nil coalescing
let name = user.name ?? "Unknown"
```

### 2. `force_cast` — 강제 캐스팅 금지

```swift
// WRONG
let cell = tableView.dequeueReusableCell(
    withIdentifier: "Cell"
) as! CustomCell

// RIGHT: 안전한 캐스팅
guard let cell = tableView.dequeueReusableCell(
    withIdentifier: "Cell"
) as? CustomCell else {
    return UITableViewCell()
}
```

### 3. `cyclomatic_complexity` — 복잡도 15 초과 (SwiftLint 값 14 초과)

```swift
// WRONG: 중첩 분기 과도
func processOrder(_ order: Order) -> Result {
    if order.type == .standard {
        if !order.items.isEmpty {
            if order.payment == .card {
                // ... 15개 이상 분기 ...
            }
        }
    }
}

// RIGHT: 전략 패턴 또는 guard + 조기 반환
func processOrder(_ order: Order) -> Result {
    guard !order.items.isEmpty else {
        return .failure(.emptyOrder)
    }

    let strategy = ProcessingStrategy.for(order.type)
    let validated = try strategy.validate(order)
    return strategy.execute(validated)
}
```

### 4. `function_body_length` — 함수 50줄 초과

```swift
// WRONG: 모든 로직이 한 함수에
func setupUI() {
    // ... 100줄의 UI 설정 ...
}

// RIGHT: 책임 분리
func setupUI() {
    setupNavigationBar()
    setupTableView()
    setupConstraints()
}

private func setupNavigationBar() { /* ... */ }
private func setupTableView() { /* ... */ }
private func setupConstraints() { /* ... */ }
```

### 5. `convenience_type` — 인스턴스 없는 타입에 enum 사용

```swift
// WRONG: 인스턴스화될 필요 없는 네임스페이스에 struct/class 사용
struct Constants {
    static let apiBaseURL = "https://api.example.com"
    static let timeout: TimeInterval = 30
}

// RIGHT: caseless enum (인스턴스 생성 불가)
enum Constants {
    static let apiBaseURL = "https://api.example.com"
    static let timeout: TimeInterval = 30
}
```

### 6. `empty_count` — .count == 0 대신 .isEmpty

```swift
// WRONG: 성능 문제 (O(n) 가능)
if items.count == 0 {
    showEmptyState()
}

// RIGHT: O(1) 보장
if items.isEmpty {
    showEmptyState()
}
```

### 7. `sorted_imports` — import 정렬

```swift
// WRONG: 정렬 안 됨
import UIKit
import Foundation
import Combine
import SwiftUI

// RIGHT: 알파벳 순 정렬 (SwiftFormat 자동 수정)
import Combine
import Foundation
import SwiftUI
import UIKit
```

---

## Apple 코딩 가이드 핵심

### struct vs class

```swift
// struct (기본 — 값 타입)
// - 불변성, 스레드 안전, 복사 시맨틱
struct User {
    let id: UUID
    let name: String
    let email: String
}

// class (참조 시맨틱이 필요할 때만)
// - 상속 필요, identity 비교, 참조 공유
final class UserSession: ObservableObject {
    @Published var currentUser: User?
}
```

### guard 패턴

```swift
// guard + 조기 반환으로 들여쓰기 최소화
func processPayment(
    amount: Decimal?,
    currency: String?,
    recipient: User?
) throws -> Receipt {
    guard let amount, amount > 0 else {
        throw PaymentError.invalidAmount
    }
    guard let currency, !currency.isEmpty else {
        throw PaymentError.invalidCurrency
    }
    guard let recipient else {
        throw PaymentError.noRecipient
    }

    return try executePayment(
        amount: amount,
        currency: currency,
        to: recipient,
    )
}
```

### Protocol-Oriented Design

```swift
// Small, composable protocols
protocol Identifiable {
    var id: UUID { get }
}

protocol Nameable {
    var name: String { get }
}

protocol Persistable: Identifiable {
    func save() async throws
    func delete() async throws
}

// Composition
struct User: Identifiable, Nameable, Persistable {
    let id: UUID
    let name: String

    func save() async throws { /* ... */ }
    func delete() async throws { /* ... */ }
}
```

---

## SwiftUI 패턴

### View 구조

```swift
struct UserProfileView: View {
    // MARK: - Properties
    let user: User

    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AvatarView(url: user.avatarURL)
                UserInfoSection(user: user)
                ActionButtonsSection(
                    isEditing: $isEditing,
                    onSave: saveChanges,
                )
            }
            .padding()
        }
        .navigationTitle(user.name)
    }

    // MARK: - Actions
    private func saveChanges() {
        // ...
        dismiss()
    }
}

// Preview
#Preview {
    NavigationStack {
        UserProfileView(user: .preview)
    }
}
```

### MVVM with @Observable

```swift
// ViewModel (iOS 17+)
@Observable
final class UserProfileViewModel {
    private(set) var user: User?
    private(set) var isLoading = false
    private(set) var error: Error?

    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func loadUser(id: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            user = try await repository.getUser(id: id)
        } catch {
            self.error = error
        }
    }
}

// View
struct UserProfileView: View {
    @State private var viewModel: UserProfileViewModel

    init(repository: UserRepository) {
        _viewModel = State(
            initialValue: UserProfileViewModel(repository: repository)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let user = viewModel.user {
                UserContent(user: user)
            } else if let error = viewModel.error {
                ErrorView(error: error)
            }
        }
        .task { await viewModel.loadUser(id: userId) }
    }
}
```

---

## Swift 코딩 체크리스트

```
타입 안전성
[ ] let 기본, var는 꼭 필요할 때만
[ ] struct 기본, class는 참조 시맨틱 필요 시만
[ ] force unwrapping (!) 0개
[ ] force cast (as!) 0개
[ ] force try (try!) 0개
[ ] guard let으로 옵셔널 안전 처리

설계
[ ] Protocol-Oriented Design (작은 프로토콜 조합)
[ ] MVVM + @Observable (iOS 17+)
[ ] final class (상속 불필요 시)
[ ] private 기본, 최소 공개
[ ] caseless enum으로 네임스페이스

품질
[ ] McCabe 복잡도 <= 15 (SwiftLint cyclomatic_complexity)
[ ] 함수 <= 50줄 (function_body_length)
[ ] 파일 <= 800줄 (file_length)
[ ] .isEmpty 사용 (.count == 0 금지)
[ ] sorted imports

테스트
[ ] 단위 테스트: XCTest 또는 Swift Testing
[ ] UI 테스트: XCUITest
[ ] 스냅샷 테스트 (선택)
[ ] 커버리지 >= 80%
[ ] @MainActor 테스트 격리

보안
[ ] 하드코딩된 시크릿 없음
[ ] Keychain으로 민감 데이터 저장
[ ] App Transport Security (ATS) 활성화
[ ] Certificate pinning (네트워크)
[ ] 입력 검증 (SQL injection, XSS)
```

---

## 품질 기준 요약 (전 언어 통일)

| 항목 | 기준값 | 도구 |
|------|--------|------|
| 커버리지 | >= 80% | swift test --enable-code-coverage |
| 복잡도 | <= 15 | SwiftLint cyclomatic_complexity |
| 함수 길이 | <= 50줄 | SwiftLint function_body_length |
| 파일 크기 | <= 800줄 | SwiftLint file_length |
| force unwrap | 0개 | SwiftLint force_unwrapping |
| 보안 취약점 | 0 critical/high | detect-secrets + Periphery |

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음

pre-push 훅 `coverage-gate` 가 리포트를 만든 뒤 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 부른다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: `origin/main` 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

전체 80% 를 처음부터 강제하지 않는 이유: 커버리지가 낮은 기존 프로젝트는 모든 PR 이 막힌다. 대신 새로 쓰는 코드는 80% 를 지키고, 전체는 한 방향으로만 오른다.

| 항목 | 내용 |
|---|---|
| 리포트 | `swift test --enable-code-coverage` 후 `llvm-cov export -format=lcov`(macOS 는 `xcrun llvm-cov`) → `.build/lcov.info` |
| 필요한 것 | Swift 툴체인(llvm-cov 포함) — Swift 6.4.1 리눅스에서 끝까지 실행해 확인 · uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage.bats` 가 lcov·JaCoCo 리포트로 바뀐 줄 80% 통과 · 79% 실패, ratchet 통과 · 실패를 확인한다.
> 언어 도구가 리포트를 만드는 부분은 그 테스트 범위 밖이다.
> 한계: 리포트에 아예 없는 파일(예: 어떤 테스트도 불러오지 않은 새 파일)은 분모에서 빠진다. 문서·테스트만 바꾼 변경은
> 측정할 줄이 없어 알림과 함께 통과한다. 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 하나도 맞지 않으면(경로 불일치) 실패한다. Java·Kotlin 소스 폴더가 다르면 `--src-roots "모듈/src/main/kotlin …"` 을 준다.
