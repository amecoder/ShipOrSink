# Prompt Caching 가이드

> **최종 수정**: 2026-05-01
> **대상**: Claude (Anthropic), GPT (OpenAI) API를 호출하는 모든 LLM 애플리케이션
> **목적**: 반복되는 시스템 프롬프트, 도구 정의, 문서 컨텍스트를 캐싱하여 토큰 비용 90%·지연 85% 절감

---

## 1. 왜 Prompt Caching인가

LLM 호출은 입력 토큰 단가가 출력 토큰의 ¼-⅕ 수준이지만, 코드 에이전트는 **거대한 시스템 프롬프트 + 도구 정의 + 코드 컨텍스트**를 매 호출 반복 전송한다. 한 세션 내 같은 프리픽스가 30회 호출되면 그만큼 비용이 누적된다.

Anthropic과 OpenAI 모두 2024년 prompt caching을 출시했다. 핵심 효과:

| 지표 | 캐시 미적용 | 캐시 적중 |
|------|-------------|-----------|
| 입력 토큰 비용 | 100% | 10% (Anthropic) / 50% (OpenAI) |
| TTFT (Time to First Token) | 100% | 15-20% |
| 적용 가능 작업 | — | 시스템 프롬프트, 도구 정의, RAG 컨텍스트, few-shot 예시 |

---

## 2. Anthropic Claude — `cache_control`

### 2.1 기본 사용법

```python
from anthropic import Anthropic

client = Anthropic()

response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": LARGE_SYSTEM_PROMPT,  # 1024 토큰 이상 권장
            "cache_control": {"type": "ephemeral"},  # 5분 캐시
        }
    ],
    tools=[
        # 도구 정의 (cache_control은 마지막 도구에 부착)
        *TOOLS[:-1],
        {**TOOLS[-1], "cache_control": {"type": "ephemeral"}},
    ],
    messages=[
        {"role": "user", "content": user_query},
    ],
)

# 응답에서 캐시 적중 확인
print(response.usage.cache_creation_input_tokens)  # 캐시 생성 (1회)
print(response.usage.cache_read_input_tokens)      # 캐시 읽기 (이후)
```

### 2.2 Cache Breakpoint 규칙

- **최대 4개**의 `cache_control` 브레이크포인트
- 브레이크포인트 위치 (앞에서 뒤로): `system → tools → messages`
- 각 브레이크포인트는 **그 이전까지의 모든 토큰을 캐시**
- TTL: `ephemeral` (5분, 기본) 또는 `1h` (Claude 4+, 1시간, 비용 +25%)

### 2.3 권장 패턴 — 4단 캐시

```python
{
    "system": [
        {"type": "text", "text": SYSTEM_PROMPT, "cache_control": {"type": "ephemeral"}},  # B1: 시스템
    ],
    "tools": [
        ...TOOLS,
        {**TOOLS[-1], "cache_control": {"type": "ephemeral"}},  # B2: 도구
    ],
    "messages": [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": LARGE_DOC, "cache_control": {"type": "ephemeral"}},  # B3: 문서
                {"type": "text", "text": SHORT_HISTORY, "cache_control": {"type": "ephemeral"}},  # B4: 대화
                {"type": "text", "text": current_query},  # 캐시 안 됨
            ],
        }
    ],
}
```

### 2.4 캐시 적중 조건

캐시는 **prefix가 정확히 일치**할 때만 적중. 다음 변경 시 무효화:
- 시스템 프롬프트 한 글자 변경 → B1부터 모두 무효
- 도구 추가/제거/순서 변경 → B2부터 무효
- 문서 한 토큰 변경 → B3부터 무효

→ **자주 변하는 부분은 뒤로**, 안정된 부분은 앞으로.

### 2.5 최소 캐시 단위

| 모델 | 최소 토큰 |
|------|-----------|
| Claude Opus 4.7 / Sonnet 4.6 | 1024 |
| Claude Haiku 4.5 | 2048 |

이 미만은 캐시 적용 안 됨.

---

## 3. OpenAI GPT — Automatic Prompt Caching

### 3.1 자동 캐싱 (코드 변경 불필요)

OpenAI는 **자동으로** prompt caching 적용. 1024 토큰 이상의 prefix가 반복되면 자동 캐시.

```python
from openai import OpenAI

client = OpenAI()

response = client.chat.completions.create(
    model="gpt-5",
    messages=[
        {"role": "developer", "content": LARGE_SYSTEM_PROMPT},  # 자동 캐시
        {"role": "user", "content": user_query},
    ],
    tools=TOOLS,  # 자동 캐시
)

# 캐시 적중 확인
print(response.usage.prompt_tokens_details.cached_tokens)
```

### 3.2 캐시 효과

- 적중 시 입력 토큰 비용 **50%** 할인 (Anthropic 90% 대비 약함)
- 자동, 별도 코드 불필요
- TTL: 5-10분 (자동, 부하에 따라 변동)
- 최소 1024 토큰

### 3.3 캐시 친화적 프롬프트 작성

```python
# WRONG: 자주 바뀌는 timestamp가 앞에 있음 → 캐시 무효
messages = [
    {"role": "developer", "content": f"Current time: {now()}\n{LARGE_PROMPT}"},
]

# RIGHT: 안정 prefix 먼저, 가변 부분은 뒤로
messages = [
    {"role": "developer", "content": LARGE_PROMPT},
    {"role": "user", "content": f"Current time: {now()}\n{user_query}"},
]
```

---

## 4. 코드 에이전트 적용 패턴

### 4.1 RAG 컨텍스트 캐싱

```python
def query_with_codebase_context(user_query: str, codebase_summary: str) -> str:
    return client.messages.create(
        model="claude-opus-4-7",
        system=[
            {"type": "text", "text": AGENT_SYSTEM_PROMPT,
             "cache_control": {"type": "ephemeral"}},
        ],
        messages=[
            {"role": "user", "content": [
                # 코드베이스 요약은 같은 세션에서 반복 사용 → 캐시
                {"type": "text", "text": codebase_summary,
                 "cache_control": {"type": "ephemeral"}},
                {"type": "text", "text": user_query},
            ]},
        ],
        max_tokens=2048,
    )
```

### 4.2 Few-shot 예시 캐싱

```python
SYSTEM_PROMPT = """You are a code reviewer. Follow these patterns:

<examples>
Example 1: ...  # 5-10개 few-shot, 5K 토큰
Example 2: ...
...
</examples>
"""

# 매 호출마다 같은 예시 반복 → 캐시 효과 큼
```

### 4.3 도구 정의 캐싱

도구 30개 정의 = 약 3-5K 토큰. 세션 내 매번 반복 → 캐시 필수.

---

## 5. 비용 분석 (실제)

### 5.1 시나리오: 코드 에이전트 1세션, 30회 호출

| 구성 요소 | 토큰 | 캐시 미적용 비용 | 캐시 적용 비용 |
|-----------|------|------------------|----------------|
| 시스템 프롬프트 | 5,000 | 30회 × 5K × $15/1M = $2.25 | 1회 캐시 작성 + 29회 읽기 = $0.30 |
| 도구 정의 (30개) | 3,000 | $1.35 | $0.18 |
| 코드베이스 컨텍스트 | 20,000 | $9.00 | $1.20 |
| **소계** | 28,000 | **$12.60** | **$1.68** |

→ **87% 절감**, 동시에 TTFT 85% 단축.

### 5.2 캐시 작성 비용 (1회)

- Anthropic: 일반 토큰의 **125%** (5분 캐시) 또는 **200%** (1시간)
- OpenAI: 추가 비용 없음 (자동)

캐시 적중이 5회 미만이면 손해. **반복 호출이 명확한 경우에만** 적용.

---

## 6. 측정 + 모니터링

### 6.1 SLI 정의

| SLI | 임계값 | 측정 |
|-----|--------|------|
| 캐시 적중률 | >= 70% | `cache_read_tokens / (cache_read + cache_creation)` |
| 평균 캐시 절감 | >= 50% | (정상 비용 - 실제 비용) / 정상 비용 |
| Cache miss 원인 | 분류 | 시스템 변경 / 도구 변경 / 문서 변경 / TTL 만료 |

### 6.2 Cost dashboard 예시 (Grafana 쿼리)

```promql
# 캐시 적중률
sum(rate(llm_cache_read_tokens[5m])) /
sum(rate(llm_cache_total_tokens[5m]))

# 캐시 절감액 (USD/일)
sum(increase(llm_input_tokens[1d])) * 15e-6 -
sum(increase(llm_actual_cost[1d]))
```

---

## 7. 안티패턴

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 시스템 프롬프트에 timestamp/UUID | 캐시 무효 | 가변 정보는 user 메시지로 |
| 도구 순서를 매번 다르게 | 캐시 무효 | 정렬 후 고정 |
| 모든 호출에 cache_control | 캐시 작성 비용만 발생 | 반복 5회 이상 확실할 때만 |
| 1024 토큰 미만 캐싱 시도 | 적용 안 됨 | 작은 프롬프트는 캐시 X |
| 1시간 TTL 남용 | 25% 추가 비용 | 5분이면 충분, 장기 컨텍스트만 1h |
| 캐시 적중률 미측정 | 절감 효과 불명 | usage 응답 로깅 필수 |

---

## 8. Decision Tree — 언제 캐싱할까

```
시스템 프롬프트 + 도구 정의 합산 ≥ 1024 토큰?
├─ No → 캐싱 X
└─ Yes
   └─ 같은 prefix가 한 세션에서 5회 이상 호출?
      ├─ No → 캐싱 X (작성 비용 손해)
      └─ Yes
         └─ 5분 이내 모든 호출 끝나는가?
            ├─ Yes → ephemeral (5분, 기본)
            └─ No → 1h TTL (25% 추가 비용 감수)
```

---

## 9. 체크리스트 (Prompt Caching 적용 시)

- [ ] 시스템 프롬프트가 1024 토큰 이상인가
- [ ] 같은 세션에서 반복 호출 ≥ 5회 예상되는가
- [ ] 시스템/도구 prefix에 timestamp/uuid 등 가변 데이터가 없는가
- [ ] 도구 정의 순서가 고정되어 있는가
- [ ] cache_control이 prefix 끝점에 정확히 위치하는가
- [ ] usage 응답의 `cache_read_input_tokens` 로깅하는가
- [ ] 캐시 적중률 모니터링 대시보드가 있는가
- [ ] 1시간 TTL 사용 시 비용 25% 증가를 정당화하는가
- [ ] 캐시 무효 트리거 (시스템/도구 변경)를 변경 관리하는가

---

## 10. 참고

- Anthropic Prompt Caching: <https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching>
- OpenAI Prompt Caching: <https://platform.openai.com/docs/guides/prompt-caching>
- 비용 분석 사례: <https://www.anthropic.com/news/prompt-caching>
