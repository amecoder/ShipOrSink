---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.sln"
---

# C# (.NET 8+) 코딩 규칙

## 불변성 및 데이터 모델링

- `record` / `record struct`를 DTO, Value Object에 기본 사용한다
- `class`는 상태 변경이 필요한 엔티티에만 사용한다
- 컬렉션은 `IReadOnlyList<T>`, `IReadOnlyDictionary<TK,TV>` 를 기본 반환 타입으로 사용한다
- `init` 접근자로 생성 시점에만 값을 설정할 수 있게 한다

```csharp
// GOOD: immutable record with positional syntax
public record OrderItem(string ProductId, int Quantity, decimal Price);

// GOOD: init-only properties for complex objects
public record Order
{
    public required string OrderId { get; init; }
    public required IReadOnlyList<OrderItem> Items { get; init; }
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
}
```

## Pattern Matching

- `switch` 식(expression)을 `if-else` 체인 대신 사용한다
- `is`, `and`, `or`, `not` 패턴을 적극 활용한다
- 분기가 exhaustive 하도록 `_` 기본 케이스를 반드시 포함한다

```csharp
// GOOD: switch expression with pattern matching
public static decimal CalculateDiscount(Customer customer) => customer switch
{
    { Tier: "Gold", OrderCount: > 100 } => 0.20m,
    { Tier: "Gold" }                    => 0.15m,
    { Tier: "Silver" }                  => 0.10m,
    { IsNewCustomer: true }             => 0.05m,
    _                                   => 0m,
};

// GOOD: list pattern (.NET 8+)
var result = numbers switch
{
    [var first, .., var last] => $"First: {first}, Last: {last}",
    [var single]              => $"Single: {single}",
    []                        => "Empty",
};
```

## Nullable Reference Types

- 프로젝트 전체에 `<Nullable>enable</Nullable>` 필수 적용
- `null` 허용 시 `?` 명시, 불필요한 `!` (null-forgiving) 사용 금지
- `ArgumentNullException.ThrowIfNull()` 로 가드 절 작성

```csharp
// GOOD: explicit nullability
public string? FindUserName(int userId)
{
    ArgumentNullException.ThrowIfNull(userId);
    return _repository.Find(userId)?.Name;
}

// BAD: null-forgiving operator hides bugs
var name = user!.Name; // NEVER
```

## async/await

- 비동기 메서드는 반드시 `Async` 접미사를 붙인다
- `Task.Run()`은 CPU-bound 작업에만 사용하고, I/O-bound에는 네이티브 async API를 사용한다
- `ConfigureAwait(false)`는 라이브러리 코드에서만 사용한다 (ASP.NET Core 앱에서는 불필요)
- 절대 `.Result` / `.Wait()` 로 동기 블로킹하지 않는다

```csharp
// GOOD: proper async pattern
public async Task<Order?> GetOrderAsync(string orderId, CancellationToken ct = default)
{
    return await _dbContext.Orders
        .Include(o => o.Items)
        .FirstOrDefaultAsync(o => o.Id == orderId, ct);
}

// BAD: sync-over-async deadlock risk
var order = GetOrderAsync(id).Result; // NEVER
```

## LINQ 패턴

- LINQ 메서드 구문(fluent)을 쿼리 구문(query syntax)보다 선호한다
- `Count() > 0` 대신 `Any()` 사용
- `Where().First()` 대신 `First(predicate)` 사용
- 대용량 데이터는 `AsNoTracking()`과 projection (`Select`)으로 성능 최적화

```csharp
// GOOD: fluent LINQ with projection
var summaries = await _dbContext.Orders
    .AsNoTracking()
    .Where(o => o.Status == OrderStatus.Active)
    .Select(o => new OrderSummary(o.Id, o.Total, o.CreatedAt))
    .ToListAsync(ct);

// BAD: unnecessary materialization
var all = await _dbContext.Orders.ToListAsync(); // loads everything
var filtered = all.Where(o => o.Status == OrderStatus.Active); // NEVER
```

## .NET 8+ 최신 기능

- **Primary Constructors**: 서비스 클래스에서 DI 매개변수를 간결하게 선언
- **Collection Expressions**: `[1, 2, 3]` 리터럴 구문 활용
- **Frozen Collections**: 읽기 전용 고성능 컬렉션 (`FrozenDictionary`, `FrozenSet`)
- **TimeProvider**: 테스트 가능한 시간 추상화

```csharp
// GOOD: primary constructor for DI (.NET 8+)
public class OrderService(IOrderRepository repository, ILogger<OrderService> logger)
{
    public async Task<Order> CreateOrderAsync(CreateOrderCommand cmd, CancellationToken ct)
    {
        logger.LogInformation("Creating order for {CustomerId}", cmd.CustomerId);
        var order = Order.Create(cmd);
        return await repository.SaveAsync(order, ct);
    }
}

// GOOD: collection expression
ReadOnlySpan<string> allowedRoles = ["Admin", "Manager", "Editor"];

// GOOD: frozen collection for hot-path lookup
private static readonly FrozenDictionary<string, int> StatusCodes =
    new Dictionary<string, int>
    {
        ["OK"] = 200,
        ["NotFound"] = 404,
        ["Error"] = 500,
    }.ToFrozenDictionary();
```

## 에러 처리

- 비즈니스 예외는 도메인별 커스텀 예외 타입을 정의한다
- `Exception` 을 직접 throw 하지 않는다
- `IExceptionHandler` (Minimal API) 또는 글로벌 미들웨어로 일괄 처리한다

## 품질 기준

| 메트릭 | 기준 |
|--------|------|
| 함수 길이 | 50줄 이하 |
| 파일 길이 | 800줄 이하 |
| 순환 복잡도 | 15 이하 |
| 테스트 커버리지 | 80% 이상 |
| Nullable 경고 | 0건 |

## 도구

| 역할 | 도구 |
|------|------|
| 린터/분석 | Roslyn Analyzers, SonarAnalyzer, StyleCop |
| 포매터 | dotnet format, CSharpier |
| 테스트 | xUnit + NSubstitute + FluentAssertions |
| 커버리지 | Coverlet + ReportGenerator |
| 보안 | Security Code Scan, OWASP Dependency Check |
