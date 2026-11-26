# Model Fallback Playbook

LLM 제공자 장애 / 레이트 리밋 / 품질 저하에 대비한 fallback 체인 표준.

## 1. 장애 유형 + 트리거

| 장애 유형 | 신호 | 권장 조치 |
|----------|------|-----------|
| Provider 다운 | HTTP 5xx, timeout > 30s | Tier 2 fallback |
| Rate limit (RPM) | HTTP 429, retry-after 헤더 | 백오프 → Tier 2 |
| Quota 초과 (월/일) | HTTP 429, "quota_exceeded" | Tier 2 또는 큐잉 |
| 모델 EOL / 제거 | HTTP 404, "model_not_found" | 즉시 Tier 2 + 코드 수정 PR |
| 품질 저하 (Drift) | Eval 점수 하락 ≥ 10% | 인간 알림 + rollback |
| 응답 형식 오류 | Parse 실패 ≥ 5% | retry → Tier 2 |
| 비용 spike | 시간당 비용 ≥ 임계값 2x | 차단 + 알림 |
| 컨텍스트 초과 | "context_length_exceeded" | 컨텍스트 압축 또는 모델 변경 |

## 2. Fallback 체인 정의

각 작업별로 **3단계** 체인을 정의:

### 2.1 단순 코드 작성

```yaml
task: code_generation
chain:
  - tier: 1
    primary: claude-sonnet-4-6
    timeout_s: 30
    max_retries: 2
  - tier: 2
    fallback: gpt-5
    trigger: ["timeout", "5xx", "429"]
    notes: "다른 provider로 전환"
  - tier: 3
    fallback: claude-haiku-4-5
    trigger: ["sustained_429", "high_cost"]
    notes: "품질 일부 양보 + 비용 절감"
```

### 2.2 복잡한 추론 (보안/아키텍처)

```yaml
task: reasoning_critical
chain:
  - tier: 1
    primary: claude-opus-4-7
    thinking: {budget_tokens: 20000}
    timeout_s: 120
  - tier: 2
    fallback: gpt-5  # o3는 더 비싸므로 일반 GPT-5
    reasoning_effort: high
    trigger: ["timeout", "5xx"]
  - tier: 3
    fallback: human_review
    trigger: ["repeated_failures", "quality_below_threshold"]
    notes: "AI 자동 처리 포기, 인간 에스컬레이트"
```

### 2.3 대규모 평가 / 배치

```yaml
task: batch_eval
chain:
  - tier: 1
    primary: gpt-5
    api: batch  # Batch API (50% 할인)
  - tier: 2
    fallback: claude-sonnet-4-6
    api: batch
    trigger: ["batch_failed", "expired"]
  - tier: 3
    fallback: degrade_to_sample
    trigger: ["all_batches_failed"]
    notes: "전체 → 통계적 샘플로 축소"
```

## 3. Fallback 구현 패턴

### 3.1 데코레이터 패턴

```python
from functools import wraps
import time

def with_fallback(chain: list[dict]):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_error = None
            for tier_config in chain:
                try:
                    return func(*args, **kwargs, model_config=tier_config)
                except RateLimitError as e:
                    last_error = e
                    backoff = e.retry_after or 30
                    if tier_config.get("respect_retry_after"):
                        time.sleep(backoff)
                        continue
                except (TimeoutError, ServerError) as e:
                    last_error = e
                    metrics.fallback_triggered.labels(
                        tier=tier_config["tier"],
                        reason=type(e).__name__,
                    ).inc()
                    continue
                except (ModelNotFoundError, AuthError) as e:
                    # 즉시 fallback (재시도 무의미)
                    last_error = e
                    continue
            raise last_error or RuntimeError("All fallbacks exhausted")
        return wrapper
    return decorator


@with_fallback(chain=CODE_GEN_CHAIN)
def generate_code(prompt: str, model_config: dict) -> str:
    client = get_client(model_config["primary"] or model_config["fallback"])
    return client.complete(prompt)
```

### 3.2 Circuit Breaker

```python
class CircuitBreaker:
    """단일 provider가 반복 실패하면 일정 시간 차단."""

    def __init__(self, failure_threshold=5, recovery_seconds=60):
        self.failures = 0
        self.opened_at = None
        self.threshold = failure_threshold
        self.recovery = recovery_seconds

    def call(self, func, *args, **kwargs):
        if self.opened_at:
            if time.time() - self.opened_at < self.recovery:
                raise CircuitOpenError()
            self.opened_at = None  # half-open
        try:
            result = func(*args, **kwargs)
            self.failures = 0
            return result
        except (TimeoutError, ServerError):
            self.failures += 1
            if self.failures >= self.threshold:
                self.opened_at = time.time()
            raise
```

## 4. 품질 게이트 (Drift 감지)

```python
def quality_check(response, baseline_metrics) -> bool:
    """모델이 정상 동작 중인지 sanity check."""
    checks = [
        len(response.text) > 10,                          # 빈 응답 X
        response.text.count("I cannot") < 3,              # 거부 폭증 X
        not is_repeating(response.text),                  # 반복 패턴 X
        json_valid(response.text) if expected_json else True,
        response.usage.completion_tokens > 5,
    ]
    if not all(checks):
        metrics.quality_check_failed.inc()
        return False
    return True
```

## 5. Provider Diversification

다중 제공자 사용 권장 (단일 의존 회피):

| 작업 | Primary | Fallback 1 | Fallback 2 |
|------|---------|------------|------------|
| 코드 작성 | Anthropic | OpenAI | (Azure OpenAI / Bedrock) |
| 추론 | Anthropic Opus | OpenAI o3 | Anthropic Sonnet |
| 임베딩 | OpenAI text-embedding-3 | Cohere | Voyage AI |
| 분류 / 단순 | OpenAI GPT-mini | Anthropic Haiku | Self-hosted (Llama 3) |

각 provider별 별도 API key + rate limit 모니터링.

## 6. Self-hosted Fallback (최후)

Cloud provider가 모두 실패할 경우:

- Llama 3.1 70B / Llama 3.3 70B (Meta)
- Mistral Large
- DeepSeek V3 / R1

자체 호스팅은 latency 5-10x, 품질 일부 저하. 비즈니스 critical은 fallback으로만 사용 (primary는 cloud).

## 7. 사용자 경험

Fallback 발생 시 사용자에게:

- 무음 fallback (선호): 사용자가 모름, 응답 받음
- 알림 fallback: "경량 모델로 응답 중입니다" 배너
- 거부: 모든 fallback 실패 시 "현재 처리 불가, 잠시 후 재시도"

응답 지연 SLA 정의:
- p50: < 3s
- p95: < 10s
- p99: < 30s (fallback 거치는 경우)

## 8. 테스트 / 카오스 엔지니어링

월 1회 실행 권장:

```python
def chaos_test():
    # 1. Primary provider를 의도적으로 차단
    inject_fault(provider="anthropic", fault="timeout", duration=300)

    # 2. 시스템이 fallback으로 잘 전환되는지
    response = generate_code("Hello")
    assert response is not None
    assert metrics.fallback_triggered.value > 0

    # 3. 복구 시 primary로 자동 복귀
    remove_fault("anthropic")
    time.sleep(60)
    response = generate_code("Hello")
    assert metrics.primary_used.value > 0
```

## 9. 체크리스트

- [ ] 각 작업 유형별 3단계 fallback 체인 정의
- [ ] 다중 provider 사용 (vendor lock-in 회피)
- [ ] Rate limit / quota 모니터링 + 알람
- [ ] Circuit breaker 구현
- [ ] 품질 sanity check (drift 감지)
- [ ] Fallback 트리거 메트릭 수집
- [ ] 카오스 테스트 월 1회
- [ ] 사용자 SLA 정의 + 사용자 알림 정책
- [ ] Provider EOL 주기적 확인 (분기별)
- [ ] On-call runbook에 fallback 절차 포함

## 10. 참고

- AWS Bedrock multi-model: <https://docs.aws.amazon.com/bedrock/>
- Anthropic API status: <https://status.anthropic.com/>
- OpenAI API status: <https://status.openai.com/>
- 본 playbook 보완: [`MODEL_CHANGE_TEMPLATE.md`](MODEL_CHANGE_TEMPLATE.md)
