# 코딩 스타일 가이드

> Google Style Guide 기반, 4개 언어(Python, Kotlin, TypeScript, Java) 통일 규칙.
> 각 언어의 린터/포매터가 자동으로 강제하는 규칙은 이 문서에서 생략하고,
> **사람이 판단해야 하는 규칙**에 집중한다.

---

## 1. 공통 원칙

### 1.1 가독성 우선

- 코드는 작성하는 시간보다 **읽히는 시간이 10배 많다**
- "영리한 코드"보다 "명확한 코드"를 선택한다
- 6개월 후의 자신(또는 동료)이 이해할 수 있는 코드를 작성한다

### 1.2 하드 리밋

| 항목 | 기준 | 린터 규칙 |
|------|------|-----------|
| 함수 길이 | ≤50줄 | Ruff PLR0915, detekt LongMethod |
| 파일 크기 | ≤800줄 (Kotlin ≤600줄) | detekt LargeClass |
| 복잡도 | McCabe/Cyclomatic ≤15 | Ruff C901, detekt CyclomaticComplexMethod |
| 매개변수 | ≤5개 | Ruff PLR0913, detekt LongParameterList |
| 중첩 깊이 | ≤4단계 | detekt NestedBlockDepth |
| 줄 길이 | Python 99자, Kotlin/Java 100자, TS 80자 | 린터 내장 |

### 1.3 제로 경고 정책

- 모든 린터/타입체커 경고를 수정한다
- 불가피한 경우에만 `noqa` / `@Suppress` 사용 + 사유 주석 필수

```python
# noqa 사용 시 반드시 사유 기재
value = complex_legacy_function()  # noqa: PLR2004 — legacy API returns magic number
```

---

## 2. 네이밍 컨벤션

### 2.1 통일표

| 요소 | Python | Kotlin | TypeScript | Java |
|------|--------|--------|------------|------|
| 변수 | `snake_case` | `camelCase` | `camelCase` | `camelCase` |
| 함수/메서드 | `snake_case` | `camelCase` | `camelCase` | `camelCase` |
| 클래스 | `PascalCase` | `PascalCase` | `PascalCase` | `PascalCase` |
| 상수 | `UPPER_SNAKE` | `UPPER_SNAKE` | `UPPER_SNAKE` | `UPPER_SNAKE` |
| 인터페이스/프로토콜 | `PascalCase` | `PascalCase` | `PascalCase` | `PascalCase` |
| Enum | `PascalCase` | `PascalCase` | `PascalCase` | `PascalCase` |
| 파일명 | `snake_case.py` | `PascalCase.kt` | `PascalCase.tsx` | `PascalCase.java` |
| 패키지 | `lowercase` | `lowercase.dot` | `@scope/kebab` | `lowercase.dot` |

### 2.2 네이밍 규칙

**공통:**
- 약어도 일반 단어처럼 취급: `XmlParser` (O), `XMLParser` (X)
- 한 글자 변수 금지 (루프 인덱스 `i`, `j`, `k` 제외)
- 의미 있는 이름: `get_user_by_id` (O), `get` (X), `data` (X), `temp` (X)
- Boolean: `is_`, `has_`, `can_`, `should_` 접두사 사용

**금지 패턴:**

| 금지 | 올바른 예 | 이유 |
|------|-----------|------|
| `data`, `info`, `temp` | `user_profile`, `order_details` | 의미 불명확 |
| `Manager`, `Handler`, `Processor` (단독) | `PaymentProcessor`, `OrderHandler` | 책임 불명확 |
| `_` 접두사 (non-private) | 접근 제어자 사용 | 언어별 규칙 혼동 |
| `impl` 접미사 | 구체적 이름 | `UserRepositoryImpl` → `PostgresUserRepository` |
| 타입 정보 반복 | 타입 시스템 활용 | `userList` → `users` |

---

## 3. 포매팅

### 3.1 통일표

| 항목 | Python | Kotlin | TypeScript | Java |
|------|--------|--------|------------|------|
| 들여쓰기 | 4 spaces | 4 spaces | 2 spaces | 2 spaces |
| 줄 길이 | 99자 | 100자 | 80자 | 100자 |
| 후행 쉼표 | 권장 | 권장 | 권장 | 허용 |
| 와일드카드 import | 금지 | 금지 | 금지 | 금지 |
| 빈 줄 | 함수간 2줄 | 멤버간 1줄 | 논리 그룹간 1줄 | 멤버간 1줄 |
| 포매터 | `ruff format` | `ktlint` | `prettier` / `biome` | `google-java-format` |

### 3.2 Import 순서

**Python:**
```python
# 1. Future imports
from __future__ import annotations

# 2. Standard library
import os
from pathlib import Path

# 3. Third-party
from fastapi import FastAPI
from pydantic import BaseModel

# 4. Local
from app.models import User
from app.services import UserService
```

**Kotlin:**
```kotlin
// ktlint이 자동 정렬 — 수동 관리 불필요
import com.example.domain.User
import com.example.service.UserService
import org.springframework.stereotype.Service
```

**TypeScript:**
```typescript
// 1. Node built-in
import path from "node:path";

// 2. Third-party
import express from "express";

// 3. Internal (absolute)
import { UserService } from "@/services/UserService";

// 4. Relative
import { formatDate } from "./utils";
```

---

## 4. 주석/문서화

### 4.1 주석 원칙

- **Why, not What** — 코드가 "무엇"을 하는지가 아니라 "왜" 하는지를 설명
- 자명한 코드에 주석 금지: ~~`// increment counter` `counter++`~~
- 주석 대신 코드를 명확하게 작성
- 주석 처리된 코드는 삭제 (VCS가 이력 보관)

### 4.2 문서화 필수 대상

| 대상 | Python | Kotlin | TypeScript | Java |
|------|--------|--------|------------|------|
| 모든 public 함수/클래스 | docstring 필수 | KDoc 필수 | TSDoc 필수 | Javadoc 필수 |
| 복잡한 알고리즘 | 인라인 주석 | 인라인 주석 | 인라인 주석 | 인라인 주석 |
| 모듈/패키지 | 모듈 docstring | package-info | 파일 헤더 | package-info |

### 4.3 언어별 형식

**Python (Google-style Docstring):**
```python
def fetch_user(user_id: int, include_deleted: bool = False) -> User:
    """Fetch a user by their unique identifier.

    Args:
        user_id: The unique identifier of the user.
        include_deleted: If True, include soft-deleted users.

    Returns:
        A User object containing the user's profile data.

    Raises:
        UserNotFoundError: If no user exists with the given ID.
    """
```

**Kotlin (KDoc):**
```kotlin
/**
 * Fetches a user by their unique identifier.
 *
 * @param userId the unique identifier of the user
 * @param includeDeleted if true, include soft-deleted users
 * @return a User object containing the user's profile data
 * @throws UserNotFoundException if no user exists with the given ID
 */
fun fetchUser(userId: Long, includeDeleted: Boolean = false): User
```

**TypeScript (TSDoc):**
```typescript
/**
 * Fetches a user by their unique identifier.
 *
 * @param userId - The unique identifier of the user
 * @param includeDeleted - If true, include soft-deleted users
 * @returns A User object containing the user's profile data
 */
async function fetchUser(
  userId: number,
  includeDeleted: boolean = false,
): Promise<User>
```

**Java (Javadoc):**
```java
/**
 * Fetches a user by their unique identifier.
 *
 * @param userId the unique identifier of the user
 * @param includeDeleted if true, include soft-deleted users
 * @return a User object containing the user's profile data
 * @throws UserNotFoundException if no user exists with the given ID
 */
public User fetchUser(long userId, boolean includeDeleted)
```

---

## 5. 언어별 핵심 패턴

### 5.1 Python

```python
# Python ≤3.12: 모든 파일 첫 줄에 추가 (권장)
# Python 3.13+: PEP 649로 대체 예정이므로 선택적
from __future__ import annotations

# Protocol > ABC (structural subtyping)
@runtime_checkable
class Repository(Protocol):
    async def find_by_id(self, id: int) -> Entity | None: ...

# frozen=True + tuple (immutability)
@dataclass(frozen=True)
class OrderItem:
    product_id: str
    quantity: int
    options: tuple[str, ...]  # list 대신 tuple

# Named constants (no magic numbers)
MIN_PASSWORD_LENGTH = 8
MAX_RETRY_COUNT = 3
CONFIDENCE_THRESHOLD = 0.7

# contextlib.suppress > try/except/pass
import contextlib
with contextlib.suppress(FileNotFoundError):
    config = load_config()

# NewType for domain primitives
from typing import NewType
UserId = NewType("UserId", int)
Email = NewType("Email", str)
```

### 5.2 Kotlin

```kotlin
// data class for immutable value objects
// Note: Kotlin List<T> is read-only view, not truly immutable.
// For true immutability, use kotlinx.collections.immutable or defensive copy.
data class OrderItem(
    val productId: String,
    val quantity: Int,
    val options: List<String>,  // read-only view (val prevents reassignment)
)

// sealed class for restricted hierarchies
sealed class PaymentResult {
    data class Success(val transactionId: String) : PaymentResult()
    data class Failure(val error: PaymentError) : PaymentResult()
}

// Extension functions for utility
fun String.toSlug(): String =
    lowercase().replace(Regex("[^a-z0-9]+"), "-").trim('-')

// Coroutine scope for structured concurrency
suspend fun processOrders(orders: List<Order>) = coroutineScope {
    orders.map { order ->
        async { processOrder(order) }
    }.awaitAll()
}

// require/check for preconditions
fun withdraw(amount: BigDecimal) {
    require(amount > BigDecimal.ZERO) { "Amount must be positive" }
    check(balance >= amount) { "Insufficient balance" }
}
```

### 5.3 TypeScript

```typescript
// Strict types — no 'any'
interface User {
  readonly id: number;
  readonly email: string;
  readonly name: string;
}

// Discriminated unions for state
type RequestState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

// const assertions for literal types
const ROLES = ["admin", "editor", "viewer"] as const;
type Role = (typeof ROLES)[number];

// Branded types for domain primitives
type UserId = number & { readonly __brand: "UserId" };
type Email = string & { readonly __brand: "Email" };

// Exhaustive switch with compile-time safety
function assertNever(x: never): never {
  throw new Error(`Unexpected value: ${x}`);
}

function handleState(state: RequestState<User>): string {
  switch (state.status) {
    case "idle":
      return "Ready";
    case "loading":
      return "Loading...";
    case "success":
      return state.data.name;
    case "error":
      return state.error.message;
    default:
      return assertNever(state); // compile error if a variant is missing
  }
}
```

### 5.4 Java

```java
// Record for immutable value objects (Java 17+)
public record OrderItem(
    String productId,
    int quantity,
    List<String> options
) {
    // Defensive copy in compact constructor
    public OrderItem {
        options = List.copyOf(options);
    }
}

// Sealed interface for restricted hierarchies (Java 17+)
public sealed interface PaymentResult
    permits PaymentSuccess, PaymentFailure {}

public record PaymentSuccess(String transactionId)
    implements PaymentResult {}
public record PaymentFailure(PaymentError error)
    implements PaymentResult {}

// Pattern matching with switch (Java 21+)
String describe(PaymentResult result) {
    return switch (result) {
        case PaymentSuccess s -> "Paid: " + s.transactionId();
        case PaymentFailure f -> "Failed: " + f.error().message();
    };
}

// Optional for nullable return values
public Optional<User> findById(long id) {
    return Optional.ofNullable(userMap.get(id));
}

// Stream API for collection operations
List<String> activeEmails = users.stream()
    .filter(User::isActive)
    .map(User::email)
    .toList();  // Java 16+ (unmodifiable list)
```

---

## 6. 에러 처리 & 로깅

### 6.1 에러 처리 원칙

- **시스템 경계에서만 catch** — 내부 코드에서는 예외를 전파, I/O 경계(API 핸들러, 메시지 컨슈머)에서 처리
- **구체적 예외 catch** — `Exception`, `Throwable` 같은 광범위 catch 금지
- **예외를 삼키지 않음** — 빈 catch 블록 금지 (Python: `contextlib.suppress` 사용)
- **사용자 메시지 ≠ 내부 로그** — 사용자에게는 안전한 메시지, 로그에는 상세 정보

**Python:**
```python
# API 경계에서 처리
@app.exception_handler(UserNotFoundError)
async def handle_not_found(request: Request, exc: UserNotFoundError):
    logger.warning("User not found: %s", exc.user_id)
    return JSONResponse(status_code=404, content={"error": "User not found"})
```

**Kotlin:**
```kotlin
// API 경계에서 처리
@ExceptionHandler(UserNotFoundException::class)
fun handleNotFound(ex: UserNotFoundException): ResponseEntity<ErrorResponse> {
    logger.warn("User not found: {}", ex.userId)
    return ResponseEntity.status(404).body(ErrorResponse("User not found"))
}
```

### 6.2 로깅 규칙

| 레벨 | 사용 시점 | 예시 |
|------|-----------|------|
| `ERROR` | 즉시 조치 필요한 장애 | DB 연결 실패, 외부 API 장애 |
| `WARN` | 잠재적 문제, 자동 복구됨 | 재시도 성공, 캐시 미스 |
| `INFO` | 주요 비즈니스 이벤트 | 주문 완료, 사용자 가입 |
| `DEBUG` | 개발/디버깅용 상세 정보 | 쿼리 파라미터, 중간 결과 |

- 프로덕션에서 `DEBUG` 레벨 비활성화
- 구조화된 로깅 사용 (JSON format 권장)
- 민감 정보(비밀번호, 토큰, 개인정보) 로깅 금지

---

## 8. 금지 패턴

| 패턴 | 이유 | 대안 |
|------|------|------|
| `any` 타입 (TS) | 타입 안전성 파괴 | `unknown` + 타입 가드 |
| `var` (Kotlin/JS) | 가변성 위험 | `val` / `const` / `let` |
| Mutable default (Python) | 공유 상태 버그 | `None` + 내부 초기화 |
| God class (>600줄) | SRP 위반 | 클래스 분리 |
| Deep nesting (>4단계) | 가독성 저하 | Early return, Guard clause |
| 주석 처리 코드 | 노이즈 | 삭제 (Git이 기억) |
| `console.log` / `print` (프로덕션) | 로그 오염 | 로깅 프레임워크 사용 |
| 하드코딩 시크릿 | 보안 사고 | 환경 변수 |
| Magic numbers | 의미 불명 | Named constants |
| 와일드카드 import | 네임스페이스 오염 | 명시적 import |

---

## 9. 린터/포매터 도구 매핑

| 언어 | 린터 | 포매터 | 타입 체크 | 보안 |
|------|------|--------|-----------|------|
| **Python** | Ruff (16 룰셋) | ruff format | mypy --strict | Ruff S (bandit) |
| **Kotlin** | detekt | ktlint | 컴파일러 내장 | OWASP Dep Check |
| **TypeScript** | ESLint (Flat Config) | Prettier / Biome | tsc --strict | ESLint security |
| **Java** | Checkstyle (Google) | google-java-format | 컴파일러 내장 | SpotBugs |

각 언어별 상세 설정은 해당 디렉토리의 `templates/` 참조:
- Python: `python/templates/pyproject-quality.toml`
- Kotlin: `kotlin-spring/templates/detekt.yml`, `quality.gradle.kts`
