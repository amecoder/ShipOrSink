# 성능 최적화 가이드

> **작성일**: 2026-03-12
> **기반 표준**: Google SRE Book, AWS Performance Efficiency Pillar, Brendan Gregg's Systems Performance
> **적용 수준**: 빅테크 기준 팀 운영표준
> **대상 언어**: Python, Go, TypeScript

---

## 목차

1. [레이턴시 버짓](#1-레이턴시-버짓)
2. [N+1 쿼리 방지](#2-n1-쿼리-방지)
3. [비동기 처리](#3-비동기-처리)
4. [연결 풀 관리](#4-연결-풀-관리)
5. [성능 메트릭](#5-성능-메트릭)
6. [프로파일링 가이드](#6-프로파일링-가이드)
7. [성능 체크리스트](#7-성능-체크리스트)

---

## 1. 레이턴시 버짓

### 1.1 SLO 기반 레이턴시 분배

전체 사용자 요청의 레이턴시 SLO에서 각 서비스/계층에 시간 예산(budget)을 할당한다. **역산 방식**으로 설계하여 각 구간이 전체 SLO를 초과하지 않도록 보장한다.

```mermaid
flowchart LR
    subgraph budget["전체 SLO: P95 < 500ms"]
        CDN["CDN / Edge\n≤ 20ms"] --> LB["로드밸런서\n≤ 5ms"]
        LB --> GW["API Gateway\n≤ 15ms"]
        GW --> APP["애플리케이션\n≤ 200ms"]
        APP --> DB["DB 쿼리\n≤ 100ms"]
        APP --> CACHE["캐시 조회\n≤ 10ms"]
        APP --> EXT["외부 API\n≤ 100ms"]
    end

    style budget fill:#E3F2FD
    style CDN fill:#4CAF50,color:#fff
    style APP fill:#FF9800,color:#fff
    style DB fill:#F44336,color:#fff
    style EXT fill:#9C27B0,color:#fff
```

### 1.2 레이턴시 등급 분류

| 등급 | 범위 | 대상 | 최적화 전략 |
|------|------|------|-------------|
| **Ultra-low** | < 5ms | 캐시 조회, 인메모리 연산 | L1 캐시, 사전 계산, 메모리 최적화 |
| **Low** | 5 -- 100ms | DB 단순 조회, Redis 조회, 내부 RPC | 인덱스 최적화, 연결 풀, 배치 처리 |
| **Medium** | 100 -- 500ms | 복합 쿼리, 외부 API 호출, 파일 I/O | 비동기 처리, 병렬화, 캐싱 |
| **Relaxed** | > 500ms | 보고서 생성, 배치 작업, 대용량 처리 | 배경 작업 큐, 스트리밍, 페이지네이션 |

### 1.3 레이턴시 버짓 분배 예시

```
전체 SLO: API P95 응답 시간 < 500ms

구간별 분배:
├── 네트워크 (CDN + LB)         :  25ms ( 5%)
├── API Gateway (인증, 라우팅)   :  15ms ( 3%)
├── 애플리케이션 로직            : 200ms (40%)
│   ├── 직렬화/역직렬화          :  10ms
│   ├── 비즈니스 로직            :  90ms
│   └── 응답 조합                : 100ms
├── 데이터 계층                  : 160ms (32%)
│   ├── 캐시 히트                :  10ms (90% 확률)
│   ├── DB 조회 (캐시 미스)      : 100ms (10% 확률)
│   └── DB 쓰기                  :  50ms
└── 여유 버퍼 (20%)             : 100ms (20%)
```

### 1.4 버짓 초과 감지

```python
from __future__ import annotations

import time
import logging
from dataclasses import dataclass
from typing import Any

logger = logging.getLogger(__name__)

LATENCY_WARN_THRESHOLD_MS = 400  # 80% of 500ms SLO
LATENCY_CRITICAL_THRESHOLD_MS = 500  # SLO limit


@dataclass(frozen=True)
class LatencyBudget:
    """Track latency budget consumption for a request."""

    operation: str
    budget_ms: float
    start_ns: int

    @staticmethod
    def start(operation: str, budget_ms: float) -> LatencyBudget:
        """Begin tracking a latency budget."""
        return LatencyBudget(
            operation=operation,
            budget_ms=budget_ms,
            start_ns=time.perf_counter_ns(),
        )

    def elapsed_ms(self) -> float:
        """Return elapsed time in milliseconds."""
        return (time.perf_counter_ns() - self.start_ns) / 1_000_000

    def remaining_ms(self) -> float:
        """Return remaining budget in milliseconds."""
        return max(0, self.budget_ms - self.elapsed_ms())

    def check(self) -> None:
        """Log warning if budget is running low."""
        elapsed = self.elapsed_ms()
        if elapsed > self.budget_ms:
            logger.warning(
                "Latency budget EXCEEDED for %s: %.1fms / %.1fms",
                self.operation, elapsed, self.budget_ms,
            )
        elif elapsed > self.budget_ms * 0.8:
            logger.warning(
                "Latency budget WARNING for %s: %.1fms / %.1fms (80%% consumed)",
                self.operation, elapsed, self.budget_ms,
            )
```

---

## 2. N+1 쿼리 방지

### 2.1 문제 정의

N+1 쿼리란 1개의 목록 쿼리 후 각 항목에 대해 N개의 추가 쿼리가 발생하는 패턴이다. 100개의 주문 목록에서 각 주문의 사용자 정보를 개별 조회하면 101개의 쿼리가 실행된다.

```
N+1 문제:
  SELECT * FROM orders LIMIT 100;           -- 1 query
  SELECT * FROM users WHERE id = 1;         -- +
  SELECT * FROM users WHERE id = 2;         -- +
  ...                                       -- +
  SELECT * FROM users WHERE id = 100;       -- = 101 queries

해결 후:
  SELECT * FROM orders LIMIT 100;           -- 1 query
  SELECT * FROM users WHERE id IN (1,2,...100);  -- 1 query = 2 queries total
```

### 2.2 SQLAlchemy (Python) 해결법

```python
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import joinedload, selectinload, subqueryload

# BAD: N+1 -- each order.user triggers a lazy load query
async def get_orders_bad(session: AsyncSession) -> list[Order]:
    result = await session.execute(select(Order).limit(100))
    orders = result.scalars().all()
    # Accessing order.user here causes N additional queries
    return orders

# GOOD: Eager loading with joinedload (single JOIN query)
async def get_orders_joinedload(session: AsyncSession) -> list[Order]:
    result = await session.execute(
        select(Order)
        .options(joinedload(Order.user))
        .limit(100)
    )
    return result.unique().scalars().all()

# GOOD: Eager loading with selectinload (separate IN query)
async def get_orders_selectinload(session: AsyncSession) -> list[Order]:
    result = await session.execute(
        select(Order)
        .options(selectinload(Order.items))
        .limit(100)
    )
    return result.scalars().all()

# GOOD: Nested eager loading for deep relationships
async def get_orders_deep(session: AsyncSession) -> list[Order]:
    result = await session.execute(
        select(Order)
        .options(
            joinedload(Order.user),
            selectinload(Order.items).selectinload(OrderItem.product),
        )
        .limit(100)
    )
    return result.unique().scalars().all()
```

**전략 선택 기준:**

| 전략 | SQL 패턴 | 적합한 경우 |
|------|----------|-------------|
| `joinedload` | LEFT JOIN | 1:1 관계, 결과 행 수 증가 없을 때 |
| `selectinload` | SELECT ... IN (...) | 1:N 관계, 컬렉션 로딩 |
| `subqueryload` | 서브쿼리 | 깊은 중첩 관계, IN 절이 너무 길어질 때 |

### 2.3 JPA (Kotlin/Java) 해결법

```kotlin
// BAD: N+1 -- default LAZY fetch triggers individual queries
@Entity
class Order(
    @ManyToOne(fetch = FetchType.LAZY)
    val user: User,

    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    val items: List<OrderItem>,
)

// GOOD: JPQL fetch join
@Query("SELECT o FROM Order o JOIN FETCH o.user WHERE o.status = :status")
fun findByStatusWithUser(@Param("status") status: OrderStatus): List<Order>

// GOOD: @EntityGraph for declarative eager loading
@EntityGraph(attributePaths = ["user", "items", "items.product"])
@Query("SELECT o FROM Order o WHERE o.status = :status")
fun findByStatusWithGraph(@Param("status") status: OrderStatus): List<Order>

// GOOD: @BatchSize for batch lazy loading (reduces N+1 to N/batchSize+1)
@Entity
class Order(
    @OneToMany(mappedBy = "order")
    @BatchSize(size = 100)
    val items: List<OrderItem>,
)
```

### 2.4 Prisma (TypeScript) 해결법

```typescript
// BAD: N+1 -- sequential queries in a loop
async function getOrdersBad() {
  const orders = await prisma.order.findMany({ take: 100 });
  // Each iteration fires a separate query
  for (const order of orders) {
    const user = await prisma.user.findUnique({
      where: { id: order.userId },
    });
  }
}

// GOOD: include (eager loading)
async function getOrdersGood() {
  const orders = await prisma.order.findMany({
    take: 100,
    include: {
      user: true,
      items: {
        include: { product: true },
      },
    },
  });
  return orders;
}

// GOOD: select for partial loading (reduces data transfer)
async function getOrdersSelective() {
  const orders = await prisma.order.findMany({
    take: 100,
    select: {
      id: true,
      status: true,
      user: { select: { id: true, name: true, email: true } },
      items: { select: { quantity: true, product: { select: { name: true, price: true } } } },
    },
  });
  return orders;
}
```

### 2.5 DataLoader 패턴 (GraphQL / 범용)

DataLoader는 동일 이벤트 루프 틱 내의 개별 조회를 자동으로 배치 처리한다.

```typescript
import DataLoader from "dataloader";

// Batch function: receives array of keys, returns array of results in same order
const userLoader = new DataLoader<string, User>(async (userIds) => {
  const users = await prisma.user.findMany({
    where: { id: { in: [...userIds] } },
  });

  // Must return results in the same order as input keys
  const userMap = new Map(users.map((u) => [u.id, u]));
  return userIds.map((id) => userMap.get(id) ?? new Error(`User ${id} not found`));
});

// Usage: individual calls are automatically batched
async function resolveOrders(orders: Order[]) {
  // These 100 calls become 1 batched SQL query
  const users = await Promise.all(orders.map((o) => userLoader.load(o.userId)));
  return orders.map((order, i) => ({ ...order, user: users[i] }));
}
```

**Python DataLoader 예시:**

```python
from __future__ import annotations

from collections.abc import Sequence
from typing import TypeVar

T = TypeVar("T")


class DataLoader:
    """Simple DataLoader for batching database lookups.

    Collects individual load() calls within the same event loop tick
    and resolves them as a single batch query.
    """

    def __init__(self, batch_fn):  # noqa: ANN001
        self._batch_fn = batch_fn
        self._cache: dict[str, Any] = {}
        self._queue: list[tuple[str, asyncio.Future]] = []

    async def load(self, key: str):  # noqa: ANN201
        """Load a single key, batching with other concurrent loads."""
        if key in self._cache:
            return self._cache[key]

        loop = asyncio.get_event_loop()
        future = loop.create_future()
        self._queue.append((key, future))

        # Schedule batch execution on next tick
        if len(self._queue) == 1:
            loop.call_soon(lambda: asyncio.ensure_future(self._dispatch()))

        result = await future
        self._cache[key] = result
        return result

    async def _dispatch(self) -> None:
        """Execute the batch function for all queued keys."""
        queue = self._queue
        self._queue = []

        keys = [k for k, _ in queue]
        results = await self._batch_fn(keys)

        for (key, future), result in zip(queue, results, strict=True):
            future.set_result(result)
```

---

## 3. 비동기 처리

### 3.1 I/O-bound vs CPU-bound 판별

| 유형 | 특성 | 해결 전략 | 예시 |
|------|------|-----------|------|
| **I/O-bound** | 네트워크, 디스크 대기 | async/await, 이벤트 루프 | DB 쿼리, HTTP 호출, 파일 읽기 |
| **CPU-bound** | 연산 집중 | 멀티프로세스, 워커 스레드 | 이미지 처리, 암호화, 데이터 변환 |

```mermaid
flowchart TD
    Q1{작업이 대부분\n대기인가?}
    Q1 -->|Yes - I/O bound| IO[async/await\n비동기 I/O]
    Q1 -->|No - CPU bound| Q2{단일 요청\n응답 시간 내 완료?}
    Q2 -->|Yes| THREAD[워커 스레드풀\nProcessPoolExecutor]
    Q2 -->|No| QUEUE[메시지 큐\n배경 작업]

    IO --> DONE[응답 반환]
    THREAD --> DONE
    QUEUE --> ACCEPTED["202 Accepted\n+ 폴링/웹소켓"]

    style IO fill:#4CAF50,color:#fff
    style THREAD fill:#FF9800,color:#fff
    style QUEUE fill:#2196F3,color:#fff
```

### 3.2 Python 비동기 처리 패턴

```python
from __future__ import annotations

import asyncio
from concurrent.futures import ProcessPoolExecutor
from functools import partial

# I/O-bound: use async/await
async def fetch_user_data(user_id: str) -> dict:
    """Fetch user data from external service (I/O-bound)."""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.example.com/users/{user_id}")
        response.raise_for_status()
        return response.json()

# Parallel I/O: use asyncio.gather for independent calls
async def get_order_details(order_id: str) -> dict:
    """Fetch order details with parallel I/O calls."""
    order, user, products = await asyncio.gather(
        fetch_order(order_id),
        fetch_user(order_id),
        fetch_products(order_id),
    )
    return {"order": order, "user": user, "products": products}

# CPU-bound: offload to process pool
_process_pool = ProcessPoolExecutor(max_workers=4)

def _resize_image_sync(image_bytes: bytes, width: int, height: int) -> bytes:
    """CPU-intensive image processing (runs in separate process)."""
    from PIL import Image
    import io

    img = Image.open(io.BytesIO(image_bytes))
    img = img.resize((width, height))
    buffer = io.BytesIO()
    img.save(buffer, format="WEBP")
    return buffer.getvalue()

async def resize_image(image_bytes: bytes, width: int, height: int) -> bytes:
    """Async wrapper for CPU-bound image resize."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        _process_pool,
        partial(_resize_image_sync, image_bytes, width, height),
    )
```

### 3.3 Go 동시성 패턴

```go
package service

import (
    "context"
    "golang.org/x/sync/errgroup"
)

// FanOut executes multiple independent calls concurrently.
func (s *OrderService) GetOrderDetails(ctx context.Context, orderID string) (*OrderDetails, error) {
    g, ctx := errgroup.WithContext(ctx)

    var order *Order
    var user *User
    var products []*Product

    g.Go(func() error {
        var err error
        order, err = s.orderRepo.FindByID(ctx, orderID)
        return err
    })

    g.Go(func() error {
        var err error
        user, err = s.userClient.GetByOrderID(ctx, orderID)
        return err
    })

    g.Go(func() error {
        var err error
        products, err = s.productClient.ListByOrderID(ctx, orderID)
        return err
    })

    if err := g.Wait(); err != nil {
        return nil, fmt.Errorf("fetching order details: %w", err)
    }

    return &OrderDetails{Order: order, User: user, Products: products}, nil
}
```

### 3.4 메시지 큐 활용 패턴

응답 시간 내에 완료할 수 없는 작업은 메시지 큐로 비동기화한다.

| 패턴 | 사용 시점 | 기술 |
|------|-----------|------|
| **Fire-and-forget** | 결과를 기다리지 않아도 되는 작업 | 이메일 발송, 로그 수집 |
| **Request-Reply** | 비동기 처리 후 결과 필요 | Correlation ID로 매칭 |
| **Dead Letter Queue** | 처리 실패 메시지 관리 | 재시도 후에도 실패 시 DLQ로 이동 |

```python
from __future__ import annotations

import json
from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class EmailTask:
    """Email sending task for async processing."""

    to: str
    subject: str
    body: str
    correlation_id: str


async def enqueue_email(redis_client, task: EmailTask) -> None:
    """Enqueue email task for background processing.

    Returns immediately -- actual sending happens asynchronously.
    """
    await redis_client.lpush(
        "queue:email",
        json.dumps(asdict(task)),
    )


# Worker (separate process)
async def email_worker(redis_client) -> None:
    """Process email tasks from the queue."""
    while True:
        _, raw = await redis_client.brpop("queue:email")
        task = EmailTask(**json.loads(raw))
        try:
            await send_email(task)
        except Exception:
            # Move to dead letter queue after max retries
            await redis_client.lpush("queue:email:dlq", raw)
```

---

## 4. 연결 풀 관리

### 4.1 연결 풀이 필요한 이유

TCP 연결 수립(3-way handshake) + TLS 핸드셰이크 비용은 매 요청마다 발생시키기에는 너무 크다. 연결 풀은 미리 생성한 연결을 재사용하여 이 비용을 제거한다.

```
연결 풀 없이:
  요청 → TCP 핸드셰이크 (1ms) → TLS (5ms) → 인증 (2ms) → 쿼리 (10ms) → 종료
  총: ~18ms (오버헤드 8ms = 44%)

연결 풀 사용:
  요청 → 풀에서 연결 획득 (0.1ms) → 쿼리 (10ms) → 풀에 반환
  총: ~10.1ms (오버헤드 0.1ms = 1%)
```

### 4.2 DB 연결 풀 설정

| 파라미터 | SQLAlchemy | HikariCP (JVM) | pgx (Go) | 권장값 |
|----------|------------|-----------------|----------|--------|
| 최소 연결 | `pool_size` | `minimumIdle` | `MinConns` | CPU 코어 수 |
| 최대 연결 | `max_overflow + pool_size` | `maximumPoolSize` | `MaxConns` | CPU 코어 수 x 2 + 디스크 수 |
| 대기 타임아웃 | `pool_timeout` | `connectionTimeout` | `MaxConnIdleTime` | 3-5s |
| 유휴 타임아웃 | `pool_recycle` | `idleTimeout` | `MaxConnIdleTime` | 300s |
| 수명 제한 | `pool_recycle` | `maxLifetime` | `MaxConnLifetime` | 1800s |
| 유효성 검사 | `pool_pre_ping` | `connectionTestQuery` | -- | 활성화 |

**HikariCP 최적 공식 (PostgreSQL):**

```
max_pool_size = (cpu_core_count * 2) + effective_spindle_count

예: 4코어 서버, SSD 1개
    = (4 * 2) + 1 = 9 (약 10으로 설정)
```

**Python (SQLAlchemy) 설정:**

```python
from __future__ import annotations

from sqlalchemy.ext.asyncio import create_async_engine

DB_POOL_SIZE = 10
DB_MAX_OVERFLOW = 10
DB_POOL_TIMEOUT_SEC = 5
DB_POOL_RECYCLE_SEC = 1800

engine = create_async_engine(
    "postgresql+asyncpg://user:pass@host:5432/db",
    pool_size=DB_POOL_SIZE,
    max_overflow=DB_MAX_OVERFLOW,
    pool_timeout=DB_POOL_TIMEOUT_SEC,
    pool_recycle=DB_POOL_RECYCLE_SEC,
    pool_pre_ping=True,  # validate connections before use
    echo=False,
)
```

**Go (pgxpool) 설정:**

```go
package database

import (
    "context"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
)

const (
    MinConns        = 4
    MaxConns        = 10
    MaxConnIdleTime = 5 * time.Minute
    MaxConnLifetime = 30 * time.Minute
    HealthCheckPeriod = 30 * time.Second
)

func NewPool(ctx context.Context, dsn string) (*pgxpool.Pool, error) {
    config, err := pgxpool.ParseConfig(dsn)
    if err != nil {
        return nil, fmt.Errorf("parsing pool config: %w", err)
    }

    config.MinConns = MinConns
    config.MaxConns = MaxConns
    config.MaxConnIdleTime = MaxConnIdleTime
    config.MaxConnLifetime = MaxConnLifetime
    config.HealthCheckPeriod = HealthCheckPeriod

    return pgxpool.NewWithConfig(ctx, config)
}
```

### 4.3 HTTP 연결 풀 설정

```python
from __future__ import annotations

import httpx

HTTP_MAX_CONNECTIONS = 100
HTTP_MAX_KEEPALIVE = 20
HTTP_TIMEOUT_SEC = 10.0
HTTP_CONNECT_TIMEOUT_SEC = 3.0

# Shared client -- create once, reuse across requests
http_client = httpx.AsyncClient(
    limits=httpx.Limits(
        max_connections=HTTP_MAX_CONNECTIONS,
        max_keepalive_connections=HTTP_MAX_KEEPALIVE,
    ),
    timeout=httpx.Timeout(
        timeout=HTTP_TIMEOUT_SEC,
        connect=HTTP_CONNECT_TIMEOUT_SEC,
    ),
)
```

```go
package httpclient

import (
    "net"
    "net/http"
    "time"
)

const (
    MaxIdleConns        = 100
    MaxIdleConnsPerHost = 10
    IdleConnTimeout     = 90 * time.Second
)

// NewClient creates an HTTP client with connection pooling.
func NewClient() *http.Client {
    return &http.Client{
        Timeout: 10 * time.Second,
        Transport: &http.Transport{
            DialContext: (&net.Dialer{
                Timeout:   3 * time.Second,
                KeepAlive: 30 * time.Second,
            }).DialContext,
            MaxIdleConns:        MaxIdleConns,
            MaxIdleConnsPerHost: MaxIdleConnsPerHost,
            IdleConnTimeout:     IdleConnTimeout,
            TLSHandshakeTimeout: 5 * time.Second,
        },
    }
}
```

### 4.4 Redis 연결 풀 설정

```python
from __future__ import annotations

import redis.asyncio as redis

REDIS_MAX_CONNECTIONS = 50
REDIS_SOCKET_TIMEOUT_SEC = 1.0
REDIS_SOCKET_CONNECT_TIMEOUT_SEC = 1.0

redis_pool = redis.ConnectionPool(
    host="redis-host",
    port=6379,
    db=0,
    max_connections=REDIS_MAX_CONNECTIONS,
    socket_timeout=REDIS_SOCKET_TIMEOUT_SEC,
    socket_connect_timeout=REDIS_SOCKET_CONNECT_TIMEOUT_SEC,
    retry_on_timeout=True,
    health_check_interval=30,
)

redis_client = redis.Redis(connection_pool=redis_pool)
```

---

## 5. 성능 메트릭

### 5.1 백분위수(Percentile) 이해

평균(average)은 소수의 극단값에 의해 왜곡되므로, 성능 측정에는 **백분위수**를 사용한다.

| 메트릭 | 의미 | 사용 목적 |
|--------|------|-----------|
| **P50 (Median)** | 전체 요청의 50%가 이 값 이하 | 일반적인 사용자 경험 파악 |
| **P95** | 전체 요청의 95%가 이 값 이하 | 대부분의 사용자 경험 보장 |
| **P99** | 전체 요청의 99%가 이 값 이하 | SLO 기준으로 가장 많이 사용 |
| **P99.9** | 전체 요청의 99.9%가 이 값 이하 | 가장 느린 사용자 경험 파악 |

**예시 해석:**

```
P50  = 45ms   → 절반의 사용자는 45ms 이내에 응답 받음
P95  = 120ms  → 95%의 사용자는 120ms 이내에 응답 받음
P99  = 850ms  → 99%의 사용자는 850ms 이내에 응답 받음
P99.9 = 2.5s  → 1000명 중 1명만 2.5초 이상 대기

주의: P99가 P50의 19배 → 테일 레이턴시 문제 존재
```

### 5.2 P50 vs P99 격차 해석

| P99 / P50 비율 | 상태 | 원인 가능성 |
|----------------|------|-------------|
| < 3x | 양호 | 일관된 성능 |
| 3x -- 10x | 주의 | GC 중단, 간헐적 느린 쿼리, 캐시 미스 |
| > 10x | 위험 | 연결 풀 고갈, 잠금 경합, 외부 서비스 타임아웃 |

### 5.3 Apdex Score

Apdex(Application Performance Index)는 사용자 만족도를 0 -- 1 사이의 단일 점수로 표현한다.

```
Apdex = (Satisfied + Tolerating / 2) / Total

Satisfied  : 응답 시간 <= T (목표 시간)
Tolerating : T < 응답 시간 <= 4T
Frustrated : 응답 시간 > 4T

예: T = 500ms
  Satisfied  (≤ 500ms) : 800건
  Tolerating (≤ 2000ms): 150건
  Frustrated (> 2000ms): 50건
  Total: 1000건

  Apdex = (800 + 150/2) / 1000 = 0.875
```

| Apdex | 등급 | 의미 |
|-------|------|------|
| 0.94 -- 1.00 | Excellent | 거의 모든 사용자가 만족 |
| 0.85 -- 0.93 | Good | 대부분의 사용자가 만족 |
| 0.70 -- 0.84 | Fair | 일부 사용자 불만 |
| 0.50 -- 0.69 | Poor | 많은 사용자 불만 |
| < 0.50 | Unacceptable | 심각한 성능 문제 |

### 5.4 메트릭 수집 (Prometheus 예시)

```python
from __future__ import annotations

from prometheus_client import Histogram, Counter

# Request duration histogram with percentile-friendly buckets
REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    labelnames=["method", "endpoint", "status"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

REQUEST_TOTAL = Counter(
    "http_requests_total",
    "Total HTTP requests",
    labelnames=["method", "endpoint", "status"],
)

# Usage in middleware
async def metrics_middleware(request, call_next):
    """Collect request metrics for Prometheus."""
    with REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path,
        status="pending",
    ).time():
        response = await call_next(request)

    REQUEST_TOTAL.labels(
        method=request.method,
        endpoint=request.url.path,
        status=str(response.status_code),
    ).inc()

    return response
```

```go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    RequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0},
        },
        []string{"method", "endpoint", "status"},
    )

    RequestTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)
```

---

## 6. 프로파일링 가이드

### 6.1 Python -- cProfile / py-spy

**cProfile (내장 프로파일러):**

```bash
# CLI profiling
python -m cProfile -s cumtime app.py

# Programmatic profiling
python -c "
import cProfile
import pstats
profiler = cProfile.Profile()
profiler.enable()
# ... code to profile ...
profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats('cumtime')
stats.print_stats(20)  # top 20 functions
"
```

**py-spy (production-safe sampling profiler):**

```bash
# Attach to running process (no restart needed)
py-spy top --pid 12345

# Generate flame graph
py-spy record -o profile.svg --pid 12345

# Profile a command
py-spy record -o profile.svg -- python app.py
```

**line_profiler (line-by-line):**

```python
from __future__ import annotations

# Decorate the function to profile
# @profile  -- uncomment when running with kernprof
def process_order(order_id: str) -> dict:
    order = fetch_order(order_id)        # Line timing
    user = fetch_user(order.user_id)     # Line timing
    total = calculate_total(order.items) # Line timing
    return {"order": order, "user": user, "total": total}

# Run: kernprof -l -v app.py
```

### 6.2 Go -- pprof

```go
package main

import (
    "net/http"
    _ "net/http/pprof" // registers pprof handlers
)

func main() {
    // Enable pprof endpoint (production: protect with auth)
    go func() {
        http.ListenAndServe("localhost:6060", nil) // pprof only on localhost
    }()

    // Application code...
}
```

```bash
# CPU profile (30 seconds)
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# Memory (heap) profile
go tool pprof http://localhost:6060/debug/pprof/heap

# Goroutine profile
go tool pprof http://localhost:6060/debug/pprof/goroutine

# Interactive commands in pprof
# (pprof) top 20        -- top 20 functions by CPU
# (pprof) list funcName -- source-level annotation
# (pprof) web           -- open flame graph in browser

# Generate flame graph directly
go tool pprof -http=:8080 http://localhost:6060/debug/pprof/profile?seconds=30
```

### 6.3 Chrome DevTools / Node.js

```bash
# Node.js built-in profiler
node --prof app.js
node --prof-process isolate-*.log > profile.txt

# Node.js inspector (Chrome DevTools)
node --inspect app.js
# Open chrome://inspect in Chrome

# Clinic.js (comprehensive profiling)
npx clinic doctor -- node app.js
npx clinic flame -- node app.js
npx clinic bubbleprof -- node app.js
```

**Chrome DevTools Performance Panel 활용법:**

```
1. F12 → Performance 탭
2. Record 클릭 후 문제 동작 실행
3. Stop 클릭 후 분석:
   - Main: JavaScript 실행 타임라인
   - Network: 리소스 로딩 순서
   - Frames: 프레임 드롭 확인
   - Summary: 시간 분배 (Scripting, Rendering, Painting)

핵심 지표:
  - Long Task (>50ms): 메인 스레드 블로킹
  - Layout Shift: CLS 원인
  - First Paint / FCP / LCP: Core Web Vitals
```

### 6.4 프로파일링 체크리스트

| 단계 | 도구 | 확인 항목 |
|------|------|-----------|
| **1. 병목 식별** | APM (Datadog, New Relic) | 가장 느린 엔드포인트, 에러율 |
| **2. CPU 분석** | py-spy, pprof, Chrome DevTools | 핫 함수, 불필요한 연산 |
| **3. 메모리 분석** | pprof heap, tracemalloc | 메모리 누수, 큰 객체 |
| **4. I/O 분석** | slow query log, tcpdump | N+1 쿼리, 느린 외부 호출 |
| **5. 동시성 분석** | goroutine dump, thread dump | 잠금 경합, 데드락 |
| **6. 검증** | 부하 테스트 (k6, locust) | 최적화 전후 비교 |

---

## 7. 성능 체크리스트

### 7.1 코드 리뷰 시 확인 항목

**데이터베이스:**

- [ ] N+1 쿼리가 발생하지 않는가 (eager loading 확인)
- [ ] 쿼리에 적절한 인덱스가 있는가 (`EXPLAIN ANALYZE` 확인)
- [ ] 대량 데이터 조회에 페이지네이션이 적용되었는가
- [ ] 불필요한 `SELECT *` 대신 필요한 컬럼만 조회하는가
- [ ] 트랜잭션 범위가 최소화되었는가
- [ ] DB 커넥션이 풀에서 관리되는가 (직접 생성/종료 금지)

**캐싱:**

- [ ] 반복 조회되는 데이터에 캐시가 적용되었는가
- [ ] 캐시 TTL이 적절하게 설정되었는가
- [ ] 캐시 무효화 전략이 명확한가
- [ ] 캐시 키가 충돌 없이 고유한가

**비동기 처리:**

- [ ] 독립적인 I/O 호출이 병렬로 실행되는가 (`asyncio.gather`, `errgroup`)
- [ ] CPU-bound 작업이 워커 프로세스/스레드로 분리되었는가
- [ ] 응답에 불필요한 동기 작업이 포함되지 않았는가 (이메일 발송 등)

**연결 관리:**

- [ ] HTTP 클라이언트가 연결 풀을 사용하는가 (매 요청 새 클라이언트 생성 금지)
- [ ] 모든 외부 호출에 타임아웃이 설정되었는가
- [ ] 연결 풀 크기가 적절한가 (과소: 병목, 과다: 리소스 낭비)

**알고리즘/데이터 구조:**

- [ ] O(n^2) 이상의 시간 복잡도가 대량 데이터에 적용되지 않았는가
- [ ] 적절한 자료구조를 사용하는가 (검색: hash map, 정렬: balanced tree)
- [ ] 불필요한 메모리 복사가 없는가

**네트워크:**

- [ ] 응답 크기가 적절한가 (불필요한 필드 제외)
- [ ] 압축(gzip/br)이 활성화되었는가
- [ ] 배치 API를 활용할 수 있는 곳에서 개별 호출을 반복하지 않는가

### 7.2 성능 테스트 기준

| 항목 | 기준 | 측정 방법 |
|------|------|-----------|
| API 응답 시간 | P95 < 500ms, P99 < 1s | k6, locust |
| 페이지 로드 | LCP < 2.5s, FID < 100ms, CLS < 0.1 | Lighthouse |
| DB 쿼리 | 단순 조회 < 50ms, 복합 < 200ms | slow query log |
| 처리량 | 예상 트래픽의 2배 이상 처리 가능 | 부하 테스트 |
| 메모리 | 부하 시 메모리 증가 후 안정화 | Grafana |
| 에러율 | < 0.1% (5xx) | Prometheus |

### 7.3 성능 회귀 방지

```yaml
# CI 파이프라인에 성능 테스트 게이트 추가
# .github/workflows/performance.yml
name: Performance Gate
on:
  pull_request:
    branches: [main]

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run k6 performance test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/performance/api_load_test.js
          flags: --out json=results.json

      - name: Check thresholds
        run: |
          # Fail PR if P95 > 500ms or error rate > 1%
          python scripts/check_performance.py results.json \
            --p95-max 500 \
            --error-rate-max 1
```

---

## 참고 자료

- [Google SRE Book -- Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Brendan Gregg -- Systems Performance, 2nd Edition](https://www.brendangregg.com/systems-performance-2nd-edition-book.html)
- [AWS Well-Architected -- Performance Efficiency Pillar](https://docs.aws.amazon.com/wellarchitected/latest/performance-efficiency-pillar/)
- [HikariCP -- About Pool Sizing](https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing)
- [DataLoader -- Batching and Caching](https://github.com/graphql/dataloader)
