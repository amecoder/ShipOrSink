# Go 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Python 대응 | Kotlin 대응 |
|------|------|-------------|-------------|
| **golangci-lint v2** | 메타 린터 (50+ 린터 통합) | ruff | detekt |
| **gofumpt** | 엄격한 포매터 (gofmt 상위호환) | ruff format | ktlint |
| **gosec** | 보안 취약점 SAST 스캐너 | bandit(S) | OWASP |
| **govulncheck** | 알려진 CVE 의존성 스캔 | pip-audit | OWASP Dep-Check |
| **go test -cover** | 커버리지 (>= 80%) | pytest-cov | JaCoCo |
| **pre-commit** | 커밋 전 자동 검사 | pre-commit (동일) | pre-commit (동일) |

## 자동 적용

```bash
cd /path/to/my-go-project
bash "$SOS_STANDARDS/go/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. golangci-lint 설정 복사

```bash
cp "$SOS_STANDARDS/go/templates/.golangci.yml" .
```

수정 포인트:
- `linters.settings.gocyclo.min-complexity`: 순환 복잡도 (템플릿 값 15 — 도구 기본값은 30)
- `linters.settings.funlen.lines`: 함수 길이 제한 (템플릿 값 50 — `func` 줄과 닫는 괄호 사이의 줄 수. 여러 줄 시그니처는 들어가고, 주석 줄은 빠지고, 빈 줄은 들어간다. `_test.go`·`cmd/` 는 제외)
- `linters.settings.revive.rules` `file-length-limit`: 파일 길이 제한 (템플릿 값 800 — 주석·빈 줄 포함 물리 줄 수)
- 네 수치(복잡도·함수·파일·커버리지)의 정본은 `common/quality-thresholds.yaml`, 실제로 막히는지는 `tests/enforcement.bats` 가 한도/한도+1 fixture 로 확인한다
- `linters.exclusions.rules`: 프로젝트별 예외 규칙
- v2 설정 파일이므로 v1 키(`linters-settings`·`issues.exclude-rules`)는 거부된다 — `golangci-lint config verify` 로 확인

### 2. .editorconfig 복사

```bash
cp "$SOS_STANDARDS/go/templates/.editorconfig" .
```

### 3. .pre-commit-config.yaml 복사

```bash
cp "$SOS_STANDARDS/go/templates/.pre-commit-config.yaml" .
```

### 4. Claude Code 훅·설정 (공통)

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 5. detect-secrets baseline + pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan \
  --exclude-files "vendor/.*" \
  --exclude-files ".*_test\.go" \
  > .secrets.baseline

pre-commit install
pre-commit install --hook-type pre-push   # gosec, govulncheck은 push 시 실행
pre-commit run --all-files                # 최초 전체 검사
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `.golangci.yml` | golangci-lint v2 설정 (20+ 린터 활성화, 빅테크 기준) |
| `.editorconfig` | 에디터 공통 설정 (tab, charset, line-length) |
| `.pre-commit-config.yaml` | commit: gofumpt + golangci-lint / push: gosec + govulncheck |

---

## 주요 명령어

```bash
# 린트 (전체)
golangci-lint run ./...

# 린트 (자동 수정 가능한 항목)
golangci-lint run --fix ./...

# 포매팅
gofumpt -w .

# 보안 검사
gosec ./...

# 취약점 스캔 (알려진 CVE)
govulncheck ./...

# 테스트 + 커버리지
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# 커버리지 임계값 확인 (CI용)
go test -coverprofile=coverage.out ./...
COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
echo "Coverage: ${COVERAGE}%"
```

---

## golangci-lint 주요 린터 설명

### 필수 린터 (기본 활성)

| 린터 | 설명 | 감지 예시 |
|------|------|-----------|
| `errcheck` | 반환된 에러를 확인하지 않는 코드 감지 | `os.Remove(f)` (에러 무시) |
| `govet` | `go vet` 기반, 의심스러운 구문 탐지 | printf 포맷 불일치, 구조체 복사 문제 |
| `staticcheck` | 150+ 정적 분석 규칙 (Go 정적 분석의 금본위) | deprecated API, 불필요한 nil 검사 |
| `unused` | 미사용 상수, 변수, 함수, 타입 감지 | 선언 후 사용하지 않는 함수 |
| `ineffassign` | 이후 사용되지 않는 변수 할당 감지 | `x = 1` 후 `x = 2` (첫 할당 무용) |

### 강력 권장 린터

| 린터 | 설명 | 감지 예시 |
|------|------|-----------|
| `gosec` | 보안 취약점 50+ 규칙 (OWASP Top 10 매핑) | SQL injection, 하드코딩된 자격 증명 |
| `revive` | golint 대체, 60+ 커스텀 규칙 | 네이밍 규칙, context 인자 위치 |
| `gocyclo` | 순환 복잡도 측정 | 복잡도 15 초과 함수 |
| `errorlint` | 에러 래핑/비교 모범 사례 강제 | `err == ErrNotFound` 대신 `errors.Is()` |
| `gocritic` | 100+ 진단 규칙 (diagnostic, style, perf) | 불필요한 타입 변환, 비효율적 append |
| `exhaustive` | enum switch 완전성 검사 | 누락된 case 감지 |
| `nilerr` | `err != nil` 체크 후 nil 반환 감지 | 에러 삼키기 방지 |
| `unparam` | 미사용 함수 파라미터 감지 | 호출 측에서 항상 같은 값 전달 |

### 2025-2026 신규 린터

| 린터 | 설명 | 감지 예시 |
|------|------|-----------|
| `modernize` | 최신 Go 관용구로 업그레이드 권장 | `strings.Cut` 사용, `slices` 패키지 활용 |
| `intrange` | Go 1.22+ 정수 범위 반복 활용 | `for i := 0; i < n; i++` -> `for i := range n` |
| `copyloopvar` | 루프 변수 복사 문제 감지 | 클로저에서 루프 변수 캡처 |
| `perfsprint` | `fmt.Sprintf` 최적화 | `strconv.Itoa(n)` 대신 `fmt.Sprintf("%d", n)` 사용 시 |

---

## 자주 나오는 위반 패턴과 수정법

### 1. errcheck -- 에러 반환값 무시

```go
// WRONG: error return value is ignored
json.Unmarshal(data, &v)
resp.Body.Close()

// RIGHT: always check errors
if err := json.Unmarshal(data, &v); err != nil {
    return fmt.Errorf("unmarshal failed: %w", err)
}
defer func() {
    if err := resp.Body.Close(); err != nil {
        log.Printf("failed to close body: %v", err)
    }
}()
```

### 2. errorlint -- 에러 비교에 errors.Is/As 사용

```go
// WRONG: direct error comparison (won't match wrapped errors)
if err == sql.ErrNoRows {
    return nil
}

// RIGHT: use errors.Is for comparison
if errors.Is(err, sql.ErrNoRows) {
    return nil
}

// WRONG: type assertion for error
if e, ok := err.(*PathError); ok {
    // ...
}

// RIGHT: use errors.As for type assertion
var pathErr *fs.PathError
if errors.As(err, &pathErr) {
    // ...
}
```

### 3. revive (context-as-argument) -- context.Context는 첫 번째 인자

```go
// WRONG: context is not the first parameter
func FetchUser(id string, ctx context.Context) (*User, error) {
    // ...
}

// RIGHT: context.Context is always the first parameter
func FetchUser(ctx context.Context, id string) (*User, error) {
    // ...
}
```

### 4. gosec (G401/G501) -- 취약한 해시 알고리즘

```go
// WRONG: weak hash algorithm (MD5, SHA1)
h := md5.New()
h := sha1.New()

// RIGHT: use SHA-256 or stronger
h := sha256.New()
```

### 5. exhaustive -- switch 문 완전성 미충족

```go
type Status int
const (
    StatusPending Status = iota
    StatusActive
    StatusClosed
)

// WRONG: missing case for StatusClosed
func HandleStatus(s Status) string {
    switch s {
    case StatusPending:
        return "pending"
    case StatusActive:
        return "active"
    }
    return ""   // unreachable but compiler doesn't know
}

// RIGHT: exhaustive switch
func HandleStatus(s Status) string {
    switch s {
    case StatusPending:
        return "pending"
    case StatusActive:
        return "active"
    case StatusClosed:
        return "closed"
    }
    return ""
}
```

### 6. prealloc -- 슬라이스 사전 할당

```go
// WRONG: slice grows dynamically in loop
var results []string
for _, item := range items {
    results = append(results, item.Name)
}

// RIGHT: preallocate when length is known
results := make([]string, 0, len(items))
for _, item := range items {
    results = append(results, item.Name)
}
```

### 7. bodyclose -- HTTP 응답 Body 닫기 누락

```go
// WRONG: response body not closed
resp, err := http.Get(url)
if err != nil {
    return err
}
// resp.Body is never closed — resource leak

// RIGHT: always defer close
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
```

### 8. nilerr -- 에러 삼키기

```go
// WRONG: err != nil but returning nil
func ReadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, nil   // swallowing the error!
    }
    // ...
}

// RIGHT: propagate the error
func ReadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read config %s: %w", path, err)
    }
    // ...
}
```

---

## Uber Go Style Guide 핵심 규칙 요약

Uber Go Style Guide는 Go 커뮤니티에서 가장 널리 참조되는 스타일 가이드 중 하나다. 주요 규칙을 요약한다.

### 에러 처리

| 규칙 | 설명 |
|------|------|
| 에러 래핑에 `fmt.Errorf("...: %w", err)` 사용 | 에러 체인 유지, `errors.Is`/`errors.As` 호환 |
| 에러 타입은 `Err` 접두사 (변수), `Error` 접미사 (타입) | `var ErrNotFound`, `type NotFoundError` |
| 에러 문자열은 소문자, 마침표 없이 | `"connection refused"` (O), `"Connection refused."` (X) |
| `errors.New`는 최상위 변수로 선언 | `var ErrFoo = errors.New("foo")` |

### 성능

| 규칙 | 설명 |
|------|------|
| `strconv` > `fmt.Sprintf` | 정수/부울 변환 시 `strconv.Itoa`, `strconv.FormatBool` |
| string-to-byte 변환 최소화 | `[]byte(s)` 호출마다 복사 발생 |
| 슬라이스 용량 사전 지정 | `make([]T, 0, hint)` |
| `sync.Pool` 활용 | 대량 할당 객체의 GC 압력 감소 |
| `t.Parallel()` 사용 | 테스트 병렬 실행으로 CI 속도 개선 |

### 구조체와 인터페이스

| 규칙 | 설명 |
|------|------|
| 인터페이스는 소비자 측에서 정의 | 생산자가 아닌, 사용하는 쪽에서 필요한 메서드만 정의 |
| 빈 인터페이스(`any`) 사용 최소화 | 가능하면 구체 타입 또는 제네릭 사용 |
| 구조체 초기화 시 필드명 명시 | `User{Name: "foo"}` (O), `User{"foo"}` (X) |
| 제로값이 유의미하게 설계 | `sync.Mutex`, `bytes.Buffer` 등은 선언만으로 사용 가능 |
| 가변 상태는 unexported 필드 + 메서드로 보호 | 캡슐화 원칙 |

### 함수 설계

| 규칙 | 설명 |
|------|------|
| `context.Context`는 항상 첫 번째 인자 | `func Do(ctx context.Context, ...)` |
| Functional Options 패턴 | 설정 가능한 구조체 대신 `WithXxx()` 옵션 함수 |
| `defer`로 리소스 정리 | 파일, 커넥션, 뮤텍스 등 |
| naked return 사용 금지 | `return err` (O), `return` (X) |
| init() 사용 최소화 | 테스트와 디버깅 어려움, 패키지 로드 순서 의존 |

### 동시성

| 규칙 | 설명 |
|------|------|
| 고루틴 생명주기를 명확히 | `errgroup`, `context.WithCancel` 활용 |
| 채널 방향 명시 | `func consume(ch <-chan Event)` |
| 경쟁 상태 방지 | `-race` 플래그로 테스트, `sync.Mutex` 또는 채널 사용 |
| `sync.Once`로 초기화 | lazy initialization에 `sync.Once.Do` |

---

## 커버리지 게이트 — 바뀐 줄 80% + 전체는 떨어지지 않음 (전체 80% 검사와 함께)

전체 커버리지 80% 검사는 그대로 두고, 그 위에 `scripts/coverage-gate.sh`(bootstrap 이 복사)를 하나 더 건다. 게이트는 두 가지를 본다.

1. **바뀐 줄**: base 브랜치 대비 이 브랜치가 바꾼 줄의 80% 이상이 테스트로 실행돼야 한다(diff-cover, 버전 고정)
2. **ratchet**: 전체 줄 커버리지가 `.coverage-baseline` 의 숫자 아래로 떨어지면 실패한다

두 검사를 함께 두는 이유(2026-11-10 결정): 전체 80% 는 바닥을 지키고, 바뀐 줄 검사는 전체 검사가 놓치는 것을 잡는다.
예를 들어 전체가 90% 인 프로젝트에 테스트 없는 새 코드 50줄을 넣어도 전체는 80% 를 넘어 통과하지만, 바뀐 줄 검사는 그 50줄이 0% 라서 막는다.
대신 전체가 80% 아래인 기존 프로젝트는 무엇을 바꾸든 먼저 전체를 80% 까지 올려야 push·PR 이 통과한다.

| 항목 | 내용 |
|---|---|
| 실행 위치 | CI 템플릿 `common/ci-templates/ci-go.yml` 의 test 잡 — PR 에서만 도는 단계 `Coverage gate (changed lines + ratchet)`. 체크아웃은 `fetch-depth: 0`(비교할 base 브랜치가 있어야 한다), base 는 `origin/${{ github.base_ref }}` |
| 리포트 | `coverage.xml` — 테스트 단계의 `coverage.out` 을 단계 `Convert coverage to Cobertura` 가 gocover-cobertura(`GOCOVER_COBERTURA_VERSION` 고정)로 바꾼다. diff-cover 는 coverprofile 을 읽지 못한다 |
| 필요한 것 | runner 의 pipx 또는 uv · Go(이미 설치되는 setup-go) |
| 로컬에서 직접 | `go test -coverprofile=coverage.out ./... && go run "github.com/boumenot/gocover-cobertura@<버전>" < coverage.out > coverage.xml && scripts/coverage-gate.sh coverage.xml` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-coverage-langs.bats` 가 실제 `go test` 와 CI 변환 단계로 만든 리포트로 게이트 단계를 실행한다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## Go 코딩 체크리스트

```
에러 처리
[] 모든 에러 반환값 확인 (errcheck)
[] errors.Is / errors.As 사용 (== 비교 금지)
[] 에러 래핑: fmt.Errorf("context: %w", err)
[] 에러 변수: var ErrXxx = errors.New("xxx")

구조
[] context.Context는 항상 첫 번째 인자
[] 인터페이스는 소비자 측에서 정의
[] 구조체 필드명 명시 초기화 (positional 금지)
[] Functional Options 패턴 (설정 5개 이상)

품질
[] 순환 복잡도 <= 15 (gocyclo)
[] 함수 <= 50줄 (funlen)
[] 파일 <= 800줄 (revive file-length-limit)
[] 매직 넘버 -> 명명된 상수
[] 슬라이스 사전 할당 (prealloc)
[] strconv > fmt.Sprintf (성능)

보안
[] gosec 경고 0개
[] 하드코딩된 시크릿 없음 (detect-secrets)
[] SQL 파라미터 바인딩 (injection 방지)
[] HTTP 응답 Body defer Close (bodyclose)

테스트
[] go test -race ./... (경쟁 상태 감지)
[] t.Parallel() 활용 (병렬 테스트)
[] 테이블 기반 테스트 (Table-Driven Tests)
[] 커버리지 >= 80%
[] 모든 public API에 GoDoc 주석
```
