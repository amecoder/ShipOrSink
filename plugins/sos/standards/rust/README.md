# Rust 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Go 대응 | Python 대응 |
|------|------|---------|-------------|
| **Clippy** | 공식 린터 (700+ 린트 규칙) | golangci-lint | ruff |
| **rustfmt** | 공식 포매터 | gofumpt | ruff format |
| **cargo-audit** | RustSec DB 기반 CVE 스캔 | govulncheck | pip-audit |
| **cargo-deny** | 라이선스 + 취약점 + 중복 의존성 | govulncheck + depguard | pip-audit + pip-licenses |
| **cargo-tarpaulin / cargo-llvm-cov** | 커버리지 (>= 80%) | go test -cover | pytest-cov |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) | pre-commit (동일) |

## 자동 적용

```bash
cd /path/to/my-rust-project
bash "$SOS_STANDARDS/rust/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. clippy.toml 복사

```bash
cp "$SOS_STANDARDS/rust/templates/clippy.toml" .
```

수정 포인트:
- `cognitive-complexity-threshold`: 인지 복잡도 (기본 15)
- `too-many-arguments-threshold`: 함수 인자 수 (기본 7)
- `too-many-lines-threshold`: 함수 길이 (기본 100)
- `disallowed-macros`: 금지 매크로 목록

### 2. rustfmt.toml 복사

```bash
cp "$SOS_STANDARDS/rust/templates/rustfmt.toml" .
```

### 3. deny.toml 복사

```bash
cp "$SOS_STANDARDS/rust/templates/deny.toml" .
```

### 4. .pre-commit-config.yaml 복사

```bash
cp "$SOS_STANDARDS/rust/templates/.pre-commit-config.yaml" .
```

### 5. Claude Code 훅·설정 (공통)

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 6. detect-secrets baseline + pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan \
  --exclude-files "target/.*" \
  > .secrets.baseline

pre-commit install
pre-commit install --hook-type pre-push   # cargo test, audit, deny는 push 시 실행
pre-commit run --all-files                # 최초 전체 검사
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `clippy.toml` | Clippy 린트 설정 (복잡도, 인자 수, 금지 매크로/메서드) |
| `rustfmt.toml` | rustfmt 포매터 설정 (edition 2024, import 그룹핑) |
| `deny.toml` | cargo-deny 설정 (라이선스 허용 목록, 취약점 차단, 중복 의존성 경고) |
| `.pre-commit-config.yaml` | commit: cargo fmt + clippy / push: cargo test + audit + deny |

---

## 주요 명령어

```bash
# 포매팅
cargo fmt                          # 전체 포맷
cargo fmt -- --check               # 포맷 검증만 (CI용)

# 린트
# cognitive_complexity(nursery)·too_many_lines(pedantic) 는 기본 꺼짐 — pre-commit 훅과 같은 플래그로 켠다
cargo clippy --all-targets --all-features -- -D warnings -W clippy::cognitive_complexity -W clippy::too_many_lines
cargo clippy --fix --allow-dirty   # 자동 수정

# 보안 검사
cargo audit                        # 알려진 CVE 스캔
cargo deny check                   # 라이선스 + 취약점 + 소스 검사
cargo deny check advisories        # 취약점만
cargo deny check licenses          # 라이선스만

# 테스트 + 커버리지
cargo test --all-features
cargo tarpaulin --out html         # 커버리지 (Linux)
cargo llvm-cov --html --open       # 커버리지 (크로스 플랫폼)

# 커버리지 임계값 확인 (CI용)
cargo llvm-cov --all-features --workspace --fail-under-lines 80
```

---

## Clippy 린트 카테고리 설명

### 카테고리별 권장 레벨

| 카테고리 | 기본 레벨 | 권장 설정 | 설명 |
|----------|----------|-----------|------|
| `clippy::correctness` | deny | **deny (유지)** | 명백한 버그 — 무조건 수정 |
| `clippy::suspicious` | warn | **deny** | 의심스러운 코드 — 거의 항상 버그 |
| `clippy::style` | warn | **warn** | 관용적 Rust 스타일 위반 |
| `clippy::complexity` | warn | **warn** | 불필요하게 복잡한 코드 |
| `clippy::perf` | warn | **warn** | 성능 개선 가능한 패턴 |
| `clippy::pedantic` | allow | **warn (선별 allow)** | 엄격한 규칙, 오탐 가능 항목만 예외 |
| `clippy::nursery` | allow | **선별 활성화** | 실험적 린트, 유용한 것만 |
| `clippy::restriction` | allow | **개별 린트만 활성화** | 절대 전체 활성화 금지 |

### 주요 린트 상세

#### correctness (deny) -- 명백한 버그

| 린트 | 설명 |
|------|------|
| `approx_constant` | `3.14` 대신 `std::f64::consts::PI` 사용 |
| `eq_op` | `x == x` 같은 동일 피연산자 비교 |
| `erasing_op` | `x * 0` 같은 결과가 항상 같은 연산 |
| `infinite_loop` | 탈출 불가능한 무한 루프 감지 |
| `uninit_assumed_init` | 미초기화 메모리 사용 |

#### suspicious (deny) -- 의심스러운 코드

| 린트 | 설명 |
|------|------|
| `suspicious_arithmetic_impl` | Add trait에서 뺄셈 수행 등 |
| `suspicious_op_assign_impl` | AddAssign에서 -= 수행 등 |
| `blanket_clippy_allow_lint` | `#[allow(clippy::all)]` 남용 |
| `empty_loop` | `loop {}` — CPU 100% 사용 |

#### pedantic (선별 활성화) -- 엄격 규칙

| 린트 | 설명 | 권장 |
|------|------|------|
| `needless_pass_by_value` | 소유권 불필요 시 참조로 전달 | warn |
| `redundant_closure_for_method_calls` | `.map(\|x\| x.to_string())` -> `.map(ToString::to_string)` | warn |
| `match_wildcard_for_single_variants` | 단일 variant에 `_` 사용 | warn |
| `uninlined_format_args` | `format!("{}", x)` vs `format!("{x}")` | allow (호환성) |
| `module_name_repetitions` | `mod foo { struct FooBar }` | allow (오탐 빈번) |
| `must_use_candidate` | 반환값 사용 안 하면 경고 후보 | allow (노이즈) |

#### restriction (개별 활성화) -- 유용한 개별 린트

| 린트 | 설명 | 권장 |
|------|------|------|
| `dbg_macro` | `dbg!()` 매크로 사용 감지 | **deny** |
| `print_stdout` | `println!()` 사용 감지 | warn |
| `print_stderr` | `eprintln!()` 사용 감지 | warn |
| `unwrap_used` | `.unwrap()` 사용 감지 | warn |
| `expect_used` | `.expect()` 사용 감지 | warn |
| `todo` | `todo!()` 매크로 사용 감지 | warn |
| `unimplemented` | `unimplemented!()` 사용 감지 | **deny** |

---

## Cargo.toml 린트 설정 (권장)

프로젝트의 `Cargo.toml`에 아래 섹션을 추가하여 Clippy 린트 레벨을 고정한다.

```toml
[lints.clippy]
# 필수 — 버그 방지
correctness = "deny"
suspicious = "deny"

# 강력 권장 — 코드 품질
style = "warn"
complexity = "warn"
perf = "warn"

# 엄격 모드 — pedantic 전체 활성 후 오탐 항목만 allow
pedantic = { level = "warn", priority = -1 }
uninlined_format_args = "allow"
no_effect_underscore_binding = "allow"
module_name_repetitions = "allow"
must_use_candidate = "allow"
missing_errors_doc = "allow"
missing_panics_doc = "allow"
# too_many_lines 는 pedantic 에 포함 — clippy.toml 의 100 이 적용된다. 인지 복잡도는 nursery 라 따로 켠다
cognitive_complexity = "warn"

# restriction 중 유용한 개별 린트만 활성화
dbg_macro = "deny"
print_stdout = "warn"
print_stderr = "warn"
unwrap_used = "warn"
expect_used = "warn"
todo = "warn"
unimplemented = "deny"

[lints.rust]
unsafe_code = "deny"
missing_docs = "warn"
```

---

## 자주 나오는 위반 패턴과 수정법

### 1. unwrap_used -- .unwrap() 사용 금지

```rust
// WRONG: panics on None/Err
let value = some_option.unwrap();
let data = fs::read_to_string("config.toml").unwrap();

// RIGHT: handle the error explicitly
let value = some_option.ok_or_else(|| AppError::NotFound("value missing"))?;
let data = fs::read_to_string("config.toml")
    .map_err(|e| AppError::Config(format!("failed to read config: {e}")))?;
```

### 2. needless_pass_by_value -- 불필요한 소유권 이전

```rust
// WRONG: takes ownership unnecessarily
fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

// RIGHT: borrow when ownership is not needed
fn greet(name: &str) -> String {
    format!("Hello, {name}!")
}
```

### 3. redundant_clone -- 불필요한 clone()

```rust
// WRONG: cloning a value that is immediately dropped
let name = user.name.clone();
drop(user);
// `name` could have taken ownership directly

// RIGHT: move instead of clone when original is no longer needed
let name = user.name;
// `user` is partially moved — do not use `user.name` after this
```

### 4. manual_map -- 수동 Option 매핑

```rust
// WRONG: manually matching Option to transform
let result = match some_option {
    Some(val) => Some(val * 2),
    None => None,
};

// RIGHT: use .map()
let result = some_option.map(|val| val * 2);
```

### 5. single_match -- 단일 매치 분기에 match 사용

```rust
// WRONG: match with only one meaningful arm
match value {
    Some(x) => do_something(x),
    _ => {},
}

// RIGHT: use if let
if let Some(x) = value {
    do_something(x);
}
```

### 6. iter_next_slice -- 비효율적 반복자 사용

```rust
// WRONG: creating iterator just to get first element
let first = items.iter().next();

// RIGHT: use direct indexing or .first()
let first = items.first();
```

### 7. large_enum_variant -- enum variant 크기 불균형

```rust
// WRONG: one variant is much larger than others
enum Message {
    Quit,
    Text(String),
    Data([u8; 4096]),  // 4KB on stack!
}

// RIGHT: box large variants
enum Message {
    Quit,
    Text(String),
    Data(Box<[u8; 4096]>),  // pointer-sized on stack
}
```

### 8. missing_errors_doc -- 에러 반환 문서 누락

```rust
// WRONG: public function returns Result but no # Errors section
pub fn connect(url: &str) -> Result<Connection, DbError> {
    // ...
}

// RIGHT: document error conditions
/// Establishes a database connection.
///
/// # Errors
///
/// Returns `DbError::InvalidUrl` if the URL format is invalid.
/// Returns `DbError::Timeout` if connection exceeds 30 seconds.
pub fn connect(url: &str) -> Result<Connection, DbError> {
    // ...
}
```

### 9. cognitive_complexity · too_many_lines · file-size-limit -- 복잡한 함수 · 긴 함수 · 긴 파일

pre-commit `cargo-clippy` 훅이 두 린트를 켜고(`-W`), `-D warnings` 가 에러로 만든다. 파일 줄 수는 clippy 에 없어 `file-size-limit` 훅이 센다.

```text
error: the function has a cognitive complexity of (16/15)
error: this function has too many lines (101/100)
FAIL: src/parser.rs (912 lines, max 800)
```

- 함수 줄 수는 본문의 코드 줄만 센다(시그니처·중괄호·빈 줄·주석 제외)
- 수정: 분기 묶음을 `match` + 작은 함수로, 단계별로 함수를 나누고, 파일은 모듈(`parser/lexer.rs`, `parser/ast.rs`)로 쪼갠다
- 꼭 필요하면 이유와 함께 `#[expect(clippy::too_many_lines, reason = "...")]` — 경고가 사라지면 expect 자체가 경고를 낸다
- 주의: 소스의 `#[allow(...)]` 는 훅의 `-W` 보다 우선해 검사를 끈다(리뷰에서 막을 것). `Cargo.toml [lints]` 의 allow 는 훅이 이긴다
- 이 검사는 로컬 pre-commit 훅이다 — `--no-verify` 나 훅 미설치면 돌지 않는다

---

## 에러 처리 가이드

### Result와 ? 연산자

Rust에서 에러 처리의 핵심은 `Result<T, E>` 타입과 `?` 연산자다.

```rust
use thiserror::Error;

// 1. 도메인 에러 정의 (라이브러리)
#[derive(Debug, Error)]
pub enum AppError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("config not found: {path}")]
    ConfigNotFound { path: String },

    #[error("validation failed: {0}")]
    Validation(String),
}

// 2. ? 연산자로 에러 전파
pub async fn get_user(pool: &PgPool, id: i64) -> Result<User, AppError> {
    let user = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await?  // sqlx::Error -> AppError::Database (From trait)
        .ok_or(AppError::Validation(format!("user {id} not found")))?;

    Ok(user)
}

// 3. 컨텍스트 추가 (anyhow — 애플리케이션 코드)
use anyhow::{Context, Result};

pub fn load_config(path: &str) -> Result<Config> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read config from {path}"))?;

    let config: Config = toml::from_str(&content)
        .with_context(|| format!("failed to parse config from {path}"))?;

    Ok(config)
}
```

### 에러 처리 원칙

| 원칙 | 설명 |
|------|------|
| **라이브러리**: `thiserror` | 구조화된 에러 타입, 호출자가 패턴 매칭 가능 |
| **애플리케이션**: `anyhow` | 유연한 에러 체인, 컨텍스트 추가 용이 |
| **경계에서 로깅** | `main()` 또는 핸들러에서만 로그, 중간 계층은 전파만 |
| **panic 금지** | `unwrap()`, `expect()`, `panic!()` 대신 `Result` 반환 |
| **에러 메시지 소문자** | `"failed to connect"` (O), `"Failed to connect"` (X) |

---

## unsafe 가이드

### unsafe를 사용해야 하는 경우

`unsafe`는 컴파일러가 보장할 수 없는 불변 조건(invariant)을 프로그래머가 직접 보장할 때만 사용한다.

| 허용되는 경우 | 예시 |
|--------------|------|
| FFI (C 라이브러리 호출) | `extern "C" { fn strlen(s: *const c_char) -> usize; }` |
| 성능 임계 경로 | bounds check 제거가 필수적인 hot loop |
| 하드웨어 직접 접근 | embedded/OS 코드에서 MMIO 레지스터 접근 |
| 안전한 추상화 구축 | `Vec`, `Arc` 등 stdlib 내부 구현 |

### unsafe 작성 규칙

```rust
// 1. SAFETY 주석 필수
// SAFETY: `ptr` is guaranteed non-null and properly aligned
// because it was just allocated via `Box::into_raw`.
let value = unsafe { *ptr };

// 2. 안전한 래퍼로 감싸기
pub fn safe_wrapper(data: &[u8]) -> u32 {
    assert!(data.len() >= 4, "buffer too small");
    // SAFETY: length is checked above, so the slice has at least 4 bytes.
    unsafe { *(data.as_ptr() as *const u32) }
}

// 3. 공개 API에는 # Safety 섹션 문서화
/// Reads a u32 from the given pointer.
///
/// # Safety
///
/// - `ptr` must be non-null and properly aligned for `u32`.
/// - `ptr` must point to a valid, initialized `u32` value.
/// - The memory must not be concurrently modified.
pub unsafe fn read_u32(ptr: *const u32) -> u32 {
    *ptr
}
```

### unsafe 감사 도구

```bash
# cargo-geiger: unsafe 코드 사용 지도 시각화
cargo install cargo-geiger
cargo geiger

# Cargo.toml에서 unsafe 전면 금지
# [lints.rust]
# unsafe_code = "deny"
```

---

## Rust 코딩 체크리스트

```
에러 처리
[] Result<T, E>와 ? 연산자 사용 (panic 금지)
[] thiserror(라이브러리) / anyhow(애플리케이션) 사용
[] 에러 메시지 소문자, 마침표 없이
[] 에러 컨텍스트 추가 (.with_context() 또는 .map_err())
[] unwrap() / expect() 사용 금지

소유권과 안전성
[] 불필요한 clone() 없음 (clippy::redundant_clone)
[] 참조(&T)로 충분한 곳에 소유권 이전 안 함
[] unsafe 블록에 // SAFETY: 주석 필수
[] unsafe_code = "deny" 설정됨
[] 하드코딩된 시크릿 없음 (detect-secrets)

코드 품질
[] clippy 경고 0개 (-D warnings)
[] 인지 복잡도 <= 15
[] 함수 <= 100줄
[] 파일 <= 800줄
[] 매직 넘버 -> 명명된 상수
[] Vec/String 사전 할당 (with_capacity)

스타일
[] rustfmt 포맷 적용됨
[] imports: std -> 외부 크레이트 -> 로컬 순서
[] 공개 API에 문서 주석 (///)
[] enum variant는 exhaustive match (wildcard 지양)

보안
[] cargo audit 경고 0개
[] cargo deny check 통과
[] SQL 파라미터 바인딩 (injection 방지)
[] 사용자 입력 검증 (deserialization 전)

테스트
[] cargo test --all-features 통과
[] 커버리지 >= 80%
[] #[should_panic] 대신 Result 반환 테스트
[] 모든 공개 API에 doc test
[] 프로퍼티 기반 테스트 고려 (proptest)
```

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음

pre-push 훅 `coverage-gate` 가 리포트를 만든 뒤 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 부른다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: `origin/main` 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

전체 80% 를 처음부터 강제하지 않는 이유: 커버리지가 낮은 기존 프로젝트는 모든 PR 이 막힌다. 대신 새로 쓰는 코드는 80% 를 지키고, 전체는 한 방향으로만 오른다.

| 항목 | 내용 |
|---|---|
| 리포트 | `cargo llvm-cov --lcov --output-path target/lcov.info` |
| 필요한 것 | `cargo install cargo-llvm-cov` (llvm-tools 는 `rustup component add llvm-tools-preview`) · uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage.bats` 가 lcov·JaCoCo 리포트로 바뀐 줄 80% 통과 · 79% 실패, ratchet 통과 · 실패를 확인한다.
> 언어 도구가 리포트를 만드는 부분은 그 테스트 범위 밖이다.
> 한계: 리포트에 아예 없는 파일(예: 어떤 테스트도 불러오지 않은 새 파일)은 분모에서 빠진다. 문서·테스트만 바꾼 변경은
> 측정할 줄이 없어 알림과 함께 통과한다. 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 하나도 맞지 않으면(경로 불일치) 실패한다. Java·Kotlin 소스 폴더가 다르면 `--src-roots "모듈/src/main/kotlin …"` 을 준다.
