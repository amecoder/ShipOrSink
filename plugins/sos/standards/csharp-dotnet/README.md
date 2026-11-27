# C# / .NET 품질 체계

> 명령의 `$SOS_STANDARDS` 는 sos 표준 폴더 경로다. 값을 구하는 법은 [표준 설명서](../README.md#설치)에 있다. Claude Code 에서는 `/sos:setup` 이 같은 적용을 대화로 해 준다.

## 포함 도구

| 도구 | 역할 | Java 대응 | Go 대응 |
|------|------|-----------|---------|
| **Roslyn Analyzers** (Microsoft.CodeAnalysis.NetAnalyzers) | 컴파일러 통합 정적 분석 (CA*) | SpotBugs | govet/staticcheck |
| **SonarAnalyzer.CSharp** | 코드 품질 + 보안 (S*) | Sonar | gosec |
| **StyleCop.Analyzers** | 코딩 스타일 검사 (SA*) | Checkstyle | gofumpt |
| **Roslynator.Analyzers** | 추가 코드 품질 규칙 (RCS*) | — | gocritic |
| **SecurityCodeScan** | 보안 취약점 SAST (SCS*) | OWASP Dep-Check | gosec |
| **dotnet-format** | 공식 포매터 + 자동 수정 | google-java-format | gofumpt |
| **Coverlet** | 커버리지 (>= 80%) | JaCoCo | go test -cover |
| **dotnet list package --vulnerable** | 알려진 CVE 의존성 스캔 | OWASP Dep-Check | govulncheck |
| **pre-commit** | 커밋 전 자동 검사 | — | — |

## 자동 적용

```bash
cd /path/to/my-dotnet-project
bash "$SOS_STANDARDS/csharp-dotnet/bootstrap.sh"
```

## 수동 적용 (단계별)

### 1. global.json 복사 (SDK 버전 고정)

```bash
cp "$SOS_STANDARDS/csharp-dotnet/templates/global.json" .
```

수정 포인트:
- `sdk.version`: 팀 표준 SDK 버전 (예: `8.0.404`, `9.0.100`)
- `sdk.rollForward`: `latestFeature`(기본) / `latestPatch` / `disable`

### 2. Directory.Build.props 복사 (솔루션 전체에 분석기 적용)

```bash
cp "$SOS_STANDARDS/csharp-dotnet/templates/Directory.Build.props" .
```

이 파일은 **같은 디렉토리와 모든 하위 .csproj에 자동으로 적용**된다. 모든 프로젝트에 다음을 강제:
- `Nullable` 활성화 + `TreatWarningsAsErrors=true`
- `AnalysisMode=AllEnabledByDefault` (Roslyn 모든 규칙 활성)
- 분석기 5종 자동 추가 (NetAnalyzers, Sonar, StyleCop, Roslynator, SecurityCodeScan)
- 테스트 프로젝트는 자동으로 `coverlet` 추가
  - ⚠ `dotnet new xunit` 이 만든 테스트 프로젝트에는 `coverlet.collector` 가 이미 들어 있어 복원이 `NU1504`(중복 PackageReference)로
    실패한다 — 테스트 `.csproj` 에서 그 줄을 지운다(2026-11-06 확인)

### 3. .editorconfig 복사

```bash
cp "$SOS_STANDARDS/csharp-dotnet/templates/.editorconfig" .
```

### 4. stylecop.json · SonarLint.xml 복사

```bash
cp "$SOS_STANDARDS/csharp-dotnet/templates/stylecop.json" .
# companyName 수정 필요
cp "$SOS_STANDARDS/csharp-dotnet/templates/SonarLint.xml" .
```

`SonarLint.xml` 은 Sonar 규칙의 **숫자**(S1541 복잡도 15 · S138 함수 50줄)를 넘긴다. `.editorconfig` 는 severity 만 정할 수 있어서,
이 파일이 없으면 Sonar 기본값 **복잡도 10 · 함수 80줄**이 적용된다 — 2026-11-06 전 템플릿이 그랬다(복잡도 11~15 정상 코드가 막히고
51~80줄 함수가 통과). `Directory.Build.props` 가 같은 폴더의 `SonarLint.xml` 을 자동으로 넘긴다.

> 주의
> - 기존 `Directory.Build.props` 를 덮어쓰지 않았다면 `<AdditionalFiles Include="$(MSBuildThisFileDirectory)SonarLint.xml" …/>` 줄을
>   직접 병합한다. 이 줄이 없으면 `SonarLint.xml` 이 있어도 기본값(10 · 80)으로 조용히 돌아간다
> - 테스트 프로젝트에도 같은 한도가 적용된다 — 기존 프로젝트는 51줄 이상인 테스트 메서드에서 새로 막힐 수 있다
> - SonarScanner for .NET(서버 품질 프로파일)을 함께 쓰면 스캐너가 자체 `SonarLint.xml` 을 넣는다 — 서버 프로파일의 S1541 · S138
>   숫자도 15 · 50 으로 맞춘다(이 조합은 실행으로 확인하지 않았다)

### 5. .pre-commit-config.yaml 복사

```bash
cp "$SOS_STANDARDS/csharp-dotnet/templates/.pre-commit-config.yaml" .
```

### 6. Claude Code 훅·설정 (공통)

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks --target .     # 공통 Claude Code 훅 + .githooks/pre-push
bash "$SOS_STANDARDS/apply.sh" --only settings --target .  # 팀 공유 .claude/settings.json (있으면 병합)
```

### 7. detect-secrets baseline + pre-commit 설치

```bash
pip install pre-commit detect-secrets
detect-secrets scan --exclude-files "(bin|obj|packages)/.*" > .secrets.baseline
pre-commit install
pre-commit install --hook-type pre-push
pre-commit run --all-files
```

### 8. dotnet restore

```bash
dotnet restore  # 분석기 패키지 다운로드
dotnet build -warnaserror  # 분석기 검증
```

---

## 포함 템플릿

| 파일 | 설명 |
|------|------|
| `global.json` | .NET SDK 버전 고정 |
| `Directory.Build.props` | 솔루션 전체에 분석기 + Nullable + WarningsAsErrors 강제 |
| `stylecop.json` | StyleCop 설정 (회사명, 문서화 규칙) |
| `SonarLint.xml` | Sonar 규칙 한도 숫자 (S1541 복잡도 15 · S138 함수 50줄) |
| `.editorconfig` | C# 코드 스타일 + Roslyn 분석기 규칙 (CA*, S*, SA*) |
| `.pre-commit-config.yaml` | commit: dotnet format / push: build + test + CVE 스캔 |

---

## 주요 명령어

```bash
# 포매팅 + 스타일 자동 수정
dotnet format

# 포매팅 검증 (CI용 — 변경사항 있으면 실패)
dotnet format --verify-no-changes --severity warn

# 빌드 + 분석기 (경고를 에러로)
dotnet build -warnaserror -p:TreatWarningsAsErrors=true

# 테스트 + 커버리지
dotnet test --collect:"XPlat Code Coverage"

# 커버리지 80% 임계값 강제 (CI용)
dotnet test -p:CollectCoverage=true \
            -p:CoverletOutputFormat=cobertura \
            -p:Threshold=80 -p:ThresholdType=line -p:ThresholdStat=total

# 알려진 CVE 의존성 스캔
dotnet list package --vulnerable --include-transitive

# 의존성 업데이트 가능 항목 확인
dotnet list package --outdated
```

---

## Roslyn 분석기 카테고리

### CA — Microsoft.CodeAnalysis.NetAnalyzers

| 카테고리 | 코드 범위 | 예시 규칙 |
|----------|-----------|-----------|
| Performance | CA1800-CA1850 | CA1822 (static 가능 메서드), CA1825 (빈 배열은 Array.Empty) |
| Security | CA2100-CA5400 | CA2100 (SQL 인젝션), CA5350 (약한 암호), CA5394 (안전하지 않은 난수) |
| Reliability | CA2000-CA2099 | CA2007 (ConfigureAwait), CA2016 (CancellationToken 전파) |
| Globalization | CA1300-CA1399 | CA1304 (CultureInfo 명시), CA1305 (IFormatProvider 명시) |
| Usage | CA2200-CA2299 | CA2208 (예외 인자 적합성), CA2245 (자기 자신에 할당) |

### S — SonarAnalyzer.CSharp

| 카테고리 | 예시 규칙 |
|----------|-----------|
| Bug | S2168 (double-check locking), S3884 (FileShare.Read 보장) |
| Vulnerability | S2068 (하드코딩된 자격 증명), S3649 (SQL 인젝션), S5042 (ZipSlip) |
| Code Smell | S138 (함수 길이), S1541 (순환 복잡도), S107 (파라미터 7개 초과) |
| Security Hotspot | S2245 (보안 컨텍스트에서 Random 금지), S4423 (약한 SSL/TLS) |

### SA — StyleCop.Analyzers

| 카테고리 | 예시 규칙 |
|----------|-----------|
| Spacing | SA1000-SA1029 |
| Readability | SA1100-SA1136 |
| Ordering | SA1200-SA1218 |
| Naming | SA1300-SA1316 |
| Maintainability | SA1400-SA1419 |
| Layout | SA1500-SA1519 |
| Documentation | SA1600-SA1652 |

---

## 자주 나오는 위반 패턴과 수정법

### 1. CA2100 — SQL 인젝션 가능성

```csharp
// WRONG: 문자열 연결로 SQL 생성
var query = $"SELECT * FROM Users WHERE Name = '{userName}'";
using var cmd = new SqlCommand(query, connection);

// RIGHT: 파라미터 바인딩
using var cmd = new SqlCommand("SELECT * FROM Users WHERE Name = @name", connection);
cmd.Parameters.AddWithValue("@name", userName);
```

### 2. CA5350 / CA5351 — 약한 / 깨진 암호 알고리즘

```csharp
// WRONG: MD5 / SHA1
using var md5 = MD5.Create();
var hash = md5.ComputeHash(data);

// RIGHT: SHA-256 또는 더 강력한 해시
using var sha256 = SHA256.Create();
var hash = sha256.ComputeHash(data);
```

### 3. CA5394 / S2245 — 보안 컨텍스트에서 System.Random 금지

```csharp
// WRONG: 보안 토큰을 Random으로 생성
var rng = new Random();
var token = rng.Next();  // 예측 가능!

// RIGHT: 암호학적 난수 생성기 사용
using var rng = RandomNumberGenerator.Create();
var bytes = new byte[32];
rng.GetBytes(bytes);
var token = Convert.ToBase64String(bytes);
```

### 4. CA2007 — ConfigureAwait(false) (라이브러리만)

```csharp
// 라이브러리 코드: 데드락 방지를 위해 ConfigureAwait(false) 명시
public async Task<User> GetUserAsync(int id)
{
    var data = await _http.GetAsync($"/users/{id}").ConfigureAwait(false);
    return await data.Content.ReadFromJsonAsync<User>().ConfigureAwait(false);
}

// 애플리케이션 코드: 기본적으로 끔 (Directory.Build.props에서 CA2007 = none)
public async Task<User> GetUser(int id) => await _http.GetFromJsonAsync<User>($"/users/{id}");
```

### 5. CS8602 — Null 역참조 가능성 (Nullable 활성)

```csharp
// WRONG: nullable 참조 역참조
public string GetName(User? user)
{
    return user.Name;  // CS8602
}

// RIGHT: null 검사 또는 null-forgiving 연산자 (확신 시)
public string GetName(User? user)
{
    ArgumentNullException.ThrowIfNull(user);
    return user.Name;
}

// 또는 null-coalescing
public string GetName(User? user) => user?.Name ?? "Unknown";
```

### 6. S138 / S1541 — 함수 길이 / 순환 복잡도

```csharp
// WRONG: 100줄짜리 함수, 10개 if/else 분기
public Order ProcessOrder(OrderRequest req)
{
    // 100 lines...
    if (req.Type == "A") { /* 30 lines */ }
    else if (req.Type == "B") { /* 30 lines */ }
    // ...
}

// RIGHT: 작은 함수로 분리, Strategy 패턴
public Order ProcessOrder(OrderRequest req)
{
    var processor = _processors[req.Type];
    return processor.Process(req);
}
```

세는 방법(`tests/enforcement-csharp.bats` 가 SonarAnalyzer 10.4 로 확인한 것만):
- S1541: `1 + 분기 수`(테스트는 `?:` 로 확인). 15 까지 통과, 16 부터 오류
- S138: 메서드 중괄호 **안쪽** 줄 수 — 두 중괄호 줄, 빈 줄, 주석만 있는 줄은 세지 않는다. 50 까지 통과, 51 부터 오류
- 커버리지: pre-push `dotnet-test` 훅이 `-p:CollectCoverage=true -p:Threshold=80` 으로 줄 커버리지 80% 미만을 막는다.
  `--collect:"XPlat Code Coverage"` 는 `Threshold` 를 읽지 않는다 — 2026-11-06 전 훅은 커버리지 50% 도 통과시켰다

### 7. CA1062 — public 메서드 인자 null 검사

```csharp
// WRONG: 공개 API에서 null 검사 없음
public void Save(User user)
{
    _repo.Add(user.Name);  // user가 null이면 NRE
}

// RIGHT: ArgumentNullException.ThrowIfNull (.NET 6+)
public void Save(User user)
{
    ArgumentNullException.ThrowIfNull(user);
    _repo.Add(user.Name);
}
```

### 8. CA1822 — static 가능 메서드

```csharp
// WRONG: 인스턴스 멤버를 사용하지 않는데 인스턴스 메서드
public class Calculator
{
    public int Add(int a, int b) => a + b;  // CA1822
}

// RIGHT: static으로
public class Calculator
{
    public static int Add(int a, int b) => a + b;
}
```

---

## 모던 C# / .NET 8+ 권장 패턴

### Records — 불변 DTO

```csharp
// 불변 데이터 객체는 record로
public record User(string Name, string Email, DateTimeOffset CreatedAt);

// with 식으로 복사 + 수정
var updated = user with { Name = "New Name" };
```

### Pattern Matching

```csharp
// switch 식 + 패턴 매칭
public string GetStatusText(Status status) => status switch
{
    Status.Active => "활성",
    Status.Inactive => "비활성",
    Status.Pending => "대기",
    _ => throw new ArgumentOutOfRangeException(nameof(status))
};

// 속성 패턴
public bool IsValidOrder(Order order) => order is { Total: > 0, Items.Count: > 0 };
```

### Nullable 참조 타입

```csharp
// Directory.Build.props에서 <Nullable>enable</Nullable> 강제
public class UserService
{
    public User? FindByEmail(string email);   // 반환값이 null 가능
    public User GetById(int id);              // 반드시 반환
}
```

### IAsyncEnumerable

```csharp
// 큰 데이터셋 스트리밍
public async IAsyncEnumerable<User> StreamUsersAsync(
    [EnumeratorCancellation] CancellationToken ct = default)
{
    await foreach (var user in _db.Users.AsAsyncEnumerable().WithCancellation(ct))
    {
        yield return user;
    }
}
```

### Span<T> / Memory<T> — 할당 최소화

```csharp
// 문자열 슬라이스 (할당 없음)
ReadOnlySpan<char> domain = email.AsSpan(email.IndexOf('@') + 1);

// Stackalloc (작은 버퍼는 스택에)
Span<byte> buffer = stackalloc byte[256];
```

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
| 실행 위치 | pre-push 훅 `coverage-gate` — 리포트를 쓰는 훅 `dotnet-test` 바로 뒤에서 돈다(같은 파일 조건) |
| 리포트 | 테스트 프로젝트마다 `coverage.cobertura.xml` — `dotnet-test` 훅의 `-p:CoverletOutputFormat=cobertura`. 여러 개면 게이트가 합쳐서(한 줄은 어느 리포트에서든 실행되면 실행된 것) 판정한다. `--collect` 수집기가 쓰는 `TestResults/` 아래 리포트는 이전 실행분이 쌓이므로 읽지 않는다 |
| 필요한 것 | uv(`uvx`) 또는 pipx · `origin/main` 이 fetch 돼 있을 것 |
| 로컬에서 직접 | `dotnet test -p:CollectCoverage=true -p:CoverletOutputFormat=cobertura && scripts/coverage-gate.sh */coverage.cobertura.xml` |
| 첫 적용 | `scripts/coverage-gate.sh <리포트> --write-baseline` → `.coverage-baseline` 커밋. 기준선이 없으면 ratchet 은 알림만 내고 건너뛴다 |
| 기준선 올리기 | 커버리지가 오르면 같은 명령으로 다시 기록해 커밋한다(사람이 결정) |

> 검증: `tests/enforcement-csharp.bats` 가 실제 `dotnet test`(coverlet)가 쓴 리포트로 `coverage-gate` 훅을 실행한다. 게이트 자체(바뀐 줄 80% 통과 · 79% 실패, ratchet, 리포트 여러 개 합산)는 `tests/enforcement-coverage.bats`.
> 한계: 리포트에 아예 없는 파일은 분모에서 빠진다. 문서·테스트만 바꾼 변경은 측정할 줄이 없어 알림과 함께 통과한다.
> 리포트마다 저장소의 파일을 하나 이상 가리켜야 한다 — 어느 한 리포트라도 하나도 맞지 않으면(경로 불일치) 다른 리포트가 맞아도 실패한다.

## C# 코딩 체크리스트

```
스타일
[] dotnet format --verify-no-changes 통과
[] var 명시적 타입 (값 타입은 var 금지, 명백한 경우 var)
[] Modifier 순서: public > private > static > readonly > async
[] using은 namespace 밖 + System 우선 정렬

null 안전성
[] <Nullable>enable</Nullable> 활성
[] CS8602 (null 역참조) 0건
[] public API는 ArgumentNullException.ThrowIfNull
[] Nullable 반환은 ?로 명시

품질
[] 순환 복잡도 <= 15 (S1541)
[] 함수 <= 50줄 (S138)
[] 파일 <= 800줄
[] 파라미터 <= 7개 (S107)
[] 매직 넘버 → const 또는 명명 enum

보안
[] CA2100 (SQL 인젝션) 0건
[] CA5350/5351 (약한 암호) 0건
[] CA5394/S2245 (안전하지 않은 Random) 0건
[] S2068 (하드코딩 자격 증명) 0건
[] dotnet list package --vulnerable: 0건

비동기
[] async 메서드는 Async 접미사
[] 라이브러리 코드는 ConfigureAwait(false)
[] CancellationToken 전파 (CA2016)
[] async void 금지 (이벤트 핸들러 제외)

테스트
[] xUnit / NUnit / MSTest 사용
[] 커버리지 >= 80% (Coverlet)
[] FluentAssertions 또는 Shouldly로 가독성
[] AAA 패턴 (Arrange / Act / Assert)
[] 테스트 메서드명: MethodName_Scenario_ExpectedBehavior
```
