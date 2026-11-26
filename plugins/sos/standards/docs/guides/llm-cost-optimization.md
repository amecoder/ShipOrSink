# LLM Cost Optimization 가이드

> **최종 수정**: 2026-05-01
> **대상**: 프로덕션 LLM 애플리케이션, 코드 에이전트, 대규모 평가 파이프라인
> **목적**: Predicted Outputs, Batch API, 모델 라우팅, 캐싱을 조합하여 LLM 비용 50-90% 절감

---

## 1. 비용 구조 이해

LLM 비용은 **입력 토큰 + 출력 토큰**의 합. 출력 토큰이 입력 대비 4-5배 비싸다 (단, reasoning model은 사고 토큰까지 추가).

| 항목 | 단가 (예: GPT-5) | 비고 |
|------|------------------|------|
| 입력 토큰 (캐시 미적중) | $2.50/1M | |
| 입력 토큰 (캐시 적중) | $0.625/1M | 75% 할인 |
| 출력 토큰 | $10.00/1M | |
| 사고 토큰 (o3 등) | 출력과 동일 | |
| Batch API | 입출력 모두 50% | 24h 비동기 |

→ **출력 토큰을 줄이는 것이 비용 절감의 핵심**.

---

## 2. Predicted Outputs (OpenAI)

### 2.1 언제 쓰나

입출력이 **유사**할 때 (코드 리팩터링, 문서 업데이트, 일부 변경). 모델이 변경 부분만 효율적으로 생성 → 속도 2-4배, 비용 절감.

### 2.2 사용 예시

```python
from openai import OpenAI

client = OpenAI()

original_code = """
def calculate(x, y):
    return x + y
"""

response = client.chat.completions.create(
    model="gpt-5",
    messages=[
        {"role": "developer", "content": "Add type hints to this function."},
        {"role": "user", "content": original_code},
    ],
    prediction={
        "type": "content",
        "content": original_code,  # 원본을 prediction으로 전달
    },
)

# 응답에 accepted/rejected prediction tokens 정보
print(response.usage.completion_tokens_details.accepted_prediction_tokens)
print(response.usage.completion_tokens_details.rejected_prediction_tokens)
```

### 2.3 적용 패턴

| 작업 | 적용성 | 절감 효과 |
|------|--------|-----------|
| 코드 리팩터링 (변수명, 타입 추가) | 매우 좋음 | 60-80% latency |
| 문서 일부 수정 | 좋음 | 50-70% |
| 번역 (유사 단어) | 보통 | 30-50% |
| 코드 신규 작성 | 부적합 | 효과 없음 |
| 자유 텍스트 생성 | 부적합 | 효과 없음 |

### 2.4 주의

- Rejected prediction tokens는 정상 비용 청구 (예측 빗나간 부분)
- 매우 다른 출력에 사용하면 오히려 비용 증가
- 출력 길이가 입력 길이의 50% 이상 다르면 효과 미미

---

## 3. Batch API (OpenAI / Anthropic)

### 3.1 언제 쓰나

**실시간 응답 불필요**한 작업:
- 대규모 골든셋 평가 (Eval)
- 데이터셋 라벨링
- 대량 코드 리뷰 (PR 일괄)
- 문서 일괄 요약
- LLM-as-a-Judge 평가

### 3.2 OpenAI Batch API

```python
# 1. JSONL 파일 준비
import json

requests = [
    {
        "custom_id": f"task-{i}",
        "method": "POST",
        "url": "/v1/chat/completions",
        "body": {
            "model": "gpt-5",
            "messages": [{"role": "user", "content": f"Review: {code}"}],
            "max_tokens": 500,
        },
    }
    for i, code in enumerate(code_samples)
]

with open("batch.jsonl", "w") as f:
    for req in requests:
        f.write(json.dumps(req) + "\n")

# 2. 업로드
batch_file = client.files.create(file=open("batch.jsonl", "rb"), purpose="batch")

# 3. 배치 생성 (24h 완료 SLA)
batch = client.batches.create(
    input_file_id=batch_file.id,
    endpoint="/v1/chat/completions",
    completion_window="24h",
)

# 4. 폴링 (또는 webhook)
while batch.status not in ["completed", "failed", "expired"]:
    time.sleep(60)
    batch = client.batches.retrieve(batch.id)

# 5. 결과 다운로드
output_content = client.files.content(batch.output_file_id).content
```

### 3.3 Anthropic Batch (Message Batches)

```python
from anthropic import Anthropic

client = Anthropic()

batch = client.messages.batches.create(
    requests=[
        {
            "custom_id": f"task-{i}",
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 500,
                "messages": [{"role": "user", "content": f"Review: {code}"}],
            },
        }
        for i, code in enumerate(code_samples)
    ]
)
# 24h SLA, 50% 비용 할인
```

### 3.4 비용 비교 (1000개 PR 리뷰)

| 방법 | 비용 (가정) | 시간 |
|------|-------------|------|
| 실시간 API | $50 | 1-2시간 (병렬) |
| Batch API | $25 | 24h 이내 |

**80% 작업이 비실시간**이라면 Batch API 적극 활용.

---

## 4. 모델 라우팅 (Cascade)

### 4.1 단계별 모델 선택

```python
def cascading_complete(query: str) -> str:
    # 1. Haiku ($0.80/1M input)
    haiku_resp = haiku.complete(query)
    if check_confidence(haiku_resp) > 0.85:
        return haiku_resp.text

    # 2. Sonnet ($3/1M input)
    sonnet_resp = sonnet.complete(query)
    if check_confidence(sonnet_resp) > 0.90:
        return sonnet_resp.text

    # 3. Opus ($15/1M input) — 5%만 도달
    return opus.complete(query, thinking={"budget_tokens": 10000}).text


def check_confidence(response) -> float:
    """LLM-as-a-Judge로 신뢰도 평가, 또는 길이/일관성 휴리스틱."""
    ...
```

### 4.2 라우팅 기준 (작업 유형별)

| 작업 | 1차 모델 | 2차 (필요 시) | 3차 |
|------|----------|---------------|------|
| 단순 분류 | Haiku | Sonnet | — |
| 코드 작성 | Sonnet | Opus | — |
| 디버깅 | Sonnet | Opus + thinking | — |
| 알고리즘 설계 | Opus | o3 | — |
| 보안 분석 | Opus + thinking | o3-high | 인간 |
| 검증 / 리뷰 | 작성과 다른 모델 (cross-model) | — | — |

---

## 5. Token 압축 + Context 관리

### 5.1 입력 토큰 줄이기

- 불필요한 데이터 제거 (로그 헤더, 주석 일부)
- 코드 minification 후 전달 (포매팅 제거)
- RAG에서 중복 / 무관 청크 필터
- 대화 히스토리 요약 (Compaction)

### 5.2 출력 토큰 줄이기

- `max_tokens` 명시 (open-ended 호출 X)
- "200자 이내로", "JSON만 반환" 명시
- Structured Output → 자유 텍스트 제거
- 스트리밍 + 조기 종료 (`stop` 파라미터)

### 5.3 압축 효과

```python
# Before: raw 코드 + 주석 + import (3000 토큰)
prompt = open("file.py").read()

# After: 관련 함수만 추출 (800 토큰)
prompt = extract_function(open("file.py").read(), "target_function")
```

→ 70% 토큰 절감.

---

## 6. 비용 모니터링 + 알람

### 6.1 메트릭

```python
LLM_COST_METRICS = {
    "input_tokens_total": Counter,
    "output_tokens_total": Counter,
    "cost_usd_total": Counter,
    "cache_hit_rate": Gauge,
    "model_distribution": Counter(labels=["model"]),
    "request_latency_ms": Histogram,
}


def log_call(model, usage, cost_usd):
    LLM_COST_METRICS["input_tokens_total"].inc(usage.input_tokens)
    LLM_COST_METRICS["output_tokens_total"].inc(usage.output_tokens)
    LLM_COST_METRICS["cost_usd_total"].inc(cost_usd)
    LLM_COST_METRICS["model_distribution"].labels(model=model).inc()
```

### 6.2 알람 임계값

| 메트릭 | 경고 | 차단 |
|--------|------|------|
| 시간당 비용 | $50 | $200 |
| 일별 비용 | $500 | $2000 |
| 단일 사용자 | $10/h | $50/h |
| 단일 세션 | $5 | $20 |
| 캐시 적중률 | < 50% | < 30% |

차단 도달 시 fallback 모델 또는 거부.

---

## 7. 비용 우선순위 결정 트리

```
실시간 응답 필요?
├─ No → Batch API (50% 할인)
└─ Yes
   └─ 입출력 유사?
      ├─ Yes → Predicted Outputs
      └─ No
         └─ 같은 prefix 반복?
            ├─ Yes → Prompt Caching (75-90% 입력 할인)
            └─ No
               └─ 작업 복잡도?
                  ├─ 단순 → Haiku / GPT-mini
                  ├─ 보통 → Sonnet / GPT-5
                  └─ 복잡 → Opus / o3 + thinking
```

---

## 8. 체크리스트

- [ ] 비실시간 작업은 Batch API 검토
- [ ] 코드 리팩터링은 Predicted Outputs 적용
- [ ] 반복 prefix는 Prompt Caching
- [ ] 모델 cascade로 가벼운 모델 먼저 시도
- [ ] `max_tokens` 명시
- [ ] 출력은 Structured Output (자유 텍스트 X)
- [ ] 입력 토큰 압축 (관련 부분만)
- [ ] 비용 메트릭 + 알람 구성
- [ ] 단일 세션 비용 상한 적용
- [ ] reasoning model은 작업 유형별 매트릭스 따라 사용

---

## 9. 참고

- OpenAI Predicted Outputs: <https://platform.openai.com/docs/guides/predicted-outputs>
- OpenAI Batch API: <https://platform.openai.com/docs/guides/batch>
- Anthropic Message Batches: <https://docs.anthropic.com/en/docs/build-with-claude/batch-processing>
- 본 가이드 보완:
  - [`prompt-caching-guide.md`](prompt-caching-guide.md) — 캐싱 상세
  - [`reasoning-models-guide.md`](reasoning-models-guide.md) — reasoning effort 매핑
