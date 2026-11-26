# Reasoning Models 가이드

> **최종 수정**: 2026-05-01
> **대상**: OpenAI o3/o4 (reasoning) + Claude Opus 4.x extended thinking 사용 코드 에이전트
> **목적**: 작업 유형별 reasoning effort / thinking budget을 매핑하여 비용·지연을 통제하면서 정확도 유지

---

## 1. Reasoning Model이란

전통적 LLM은 한 번에 답을 생성한다. **Reasoning model**은 답 전에 내부적으로 사고 단계(chain-of-thought)를 토큰으로 생성하고, 이 사고를 사용자에게 일부 노출한다.

| 특성 | 일반 모델 (GPT-5, Claude Sonnet) | Reasoning 모델 (o3, Claude Opus thinking) |
|------|----------------------------------|-------------------------------------------|
| 사고 토큰 | 없음 (직접 답) | 있음 (수천~수만) |
| 정확도 (복잡한 추론) | 70-85% | 90-95% |
| 비용 | 1x | 5-15x (사고 토큰만큼) |
| 지연 | 1x | 3-10x |
| 강점 | 코드 작성, 요약, 변환 | 알고리즘 설계, 보안 분석, 수학 |

**오해**: "추론 모델이 항상 더 좋다." 단순 작업에 reasoning을 쓰면 비용/지연만 폭증, 정확도 향상 미미.

---

## 2. 모델별 제어 파라미터

### 2.1 OpenAI o3 / o4 — `reasoning_effort`

```python
response = client.chat.completions.create(
    model="o3",
    messages=[...],
    reasoning_effort="medium",  # "low" | "medium" | "high"
    max_completion_tokens=25000,  # reasoning 토큰을 위한 충분한 공간
)
```

| 값 | 사고 토큰 (대략) | 비용 (입력 토큰 대비) | 지연 |
|----|-----------------|-----------------------|------|
| low | 1K-3K | 5x | 5x |
| medium | 5K-10K | 10x | 10x |
| high | 20K-50K | 30x | 30x |

### 2.2 Claude Opus 4.x — extended thinking

```python
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=4096,
    thinking={
        "type": "enabled",
        "budget_tokens": 10000,  # 사고 토큰 한도
    },
    messages=[...],
)

# response.content는 thinking + text 블록 혼합
for block in response.content:
    if block.type == "thinking":
        print("Internal:", block.thinking)
    elif block.type == "text":
        print("Answer:", block.text)
```

`budget_tokens`는 **상한**이지 의무는 아님. 모델이 필요한 만큼만 사용.

| budget_tokens | 권장 작업 |
|---------------|-----------|
| 1024-3000 | 단순 코드 분석, 짧은 디버깅 |
| 5000-10000 | 다중 파일 리팩터링, 보안 리뷰 |
| 16000-32000 | 아키텍처 설계, 복잡한 알고리즘 |
| 32000+ | 큰 마이그레이션, 까다로운 디버깅 |

---

## 3. 작업 유형별 매핑

| 작업 유형 | 모델 | Reasoning | 근거 |
|-----------|------|-----------|------|
| 타이포 / 포매팅 | Haiku 4.5 / GPT-5-mini | OFF | 추론 불필요 |
| 단일 함수 작성 | Sonnet 4.6 / GPT-5 | OFF 또는 minimum | 일반 LLM 충분 |
| 다중 파일 리팩터링 | Sonnet 4.6 | budget=5000 또는 effort=low | 단계 추적 필요 |
| 버그 디버깅 (복잡) | Opus 4.7 | budget=10000 또는 effort=medium | 가설 → 검증 반복 |
| 알고리즘 설계 | Opus 4.7 / o3 | budget=20000 또는 effort=high | 깊은 추론 |
| 보안 리뷰 | Opus 4.7 / o3 | budget=15000 또는 effort=high | 적대적 사고 필요 |
| 아키텍처 결정 | Opus 4.7 / o3 | budget=25000 또는 effort=high | 트레이드오프 분석 |
| Plan Mode | Opus 4.7 + thinking | budget=10000 | 체계적 계획 |
| 코드 생성 (대규모) | Codex (GPT-5.4 xhigh) | high | 일관성 + 추론 |
| 단순 분류 / 추출 | Haiku / GPT-5-mini | OFF | 비용 |

---

## 4. 비용 최적화 결정 규칙

### 4.1 Cascade 패턴

```python
def smart_solve(problem: str) -> str:
    # 1단계: Haiku로 simple 시도
    simple_attempt = haiku.complete(problem, max_tokens=500)
    if is_confident(simple_attempt):
        return simple_attempt

    # 2단계: Sonnet으로 escalate
    medium_attempt = sonnet.complete(problem, max_tokens=2000)
    if is_confident(medium_attempt):
        return medium_attempt

    # 3단계: Opus + thinking
    return opus.complete(
        problem,
        thinking={"type": "enabled", "budget_tokens": 20000},
        max_tokens=4096,
    )
```

**기준**: 90%의 작업은 1-2단계에서 해결, 10%만 3단계 진입 → 평균 비용 80% 절감.

### 4.2 Reasoning ON 트리거

다음 조건 중 하나 이상 충족 시 reasoning ON:

- 알고리즘 / 자료구조 설계
- 보안 취약점 분석
- 동시성 / 스레드 안전성
- DB 마이그레이션 영향 분석
- 분산 시스템 합의 / 트랜잭션
- 회귀 디버깅 (3회 이상 실패)
- 사용자가 명시적 `--think-hard` / `--ultrathink` 요청

### 4.3 Reasoning OFF 강제

다음은 reasoning 사용 금지 (낭비):

- 포매팅 / 린트 수정
- 단순 변수명 변경
- 한 줄 추가/삭제
- 파일 읽기 / grep
- 사용자 질문 답변
- 문서 요약

---

## 5. 사고 토큰 관리

### 5.1 사고 → 응답 비율 모니터링

```python
def log_thinking_efficiency(response):
    thinking_tokens = sum(
        len(b.thinking.split()) for b in response.content
        if b.type == "thinking"
    )
    output_tokens = sum(
        len(b.text.split()) for b in response.content
        if b.type == "text"
    )
    ratio = thinking_tokens / max(output_tokens, 1)
    logger.info(f"thinking/output ratio: {ratio:.2f}")
```

| 비율 | 의미 | 조치 |
|------|------|------|
| < 1 | 사고가 부족 또는 단순 작업 | budget 줄이거나 OFF |
| 1-3 | 정상 | 유지 |
| 3-10 | 복잡한 추론 | 정상 (어려운 문제) |
| > 10 | 과추론 또는 루프 | budget 상한 낮추기 |

### 5.2 사고 토큰 노출 — 사용자 경험

- 사용자에게 사고 과정 그대로 보이기 X (정보 과부하)
- 요약: "분석 중... 3개 가설 검토 → 2개 기각 → 1개 채택"
- 디버깅 모드에서만 전체 사고 노출

---

## 6. 사고 토큰 + 캐싱 동시 적용

Anthropic은 thinking + prompt caching 호환:

```python
response = client.messages.create(
    model="claude-opus-4-7",
    system=[
        {"type": "text", "text": LARGE_PROMPT, "cache_control": {"type": "ephemeral"}},
    ],
    thinking={"type": "enabled", "budget_tokens": 10000},
    messages=[...],
)
```

캐시 적중 + reasoning 동시 적용으로 비용 효율 극대화.

---

## 7. 안티패턴

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 모든 호출에 `reasoning_effort: "high"` | 비용 30x 폭증 | 작업별 매핑 |
| 단순 작업에 thinking ON | 응답 지연 5-10x | OFF |
| budget_tokens 부족 (1000) | 사고 중간에 잘림 | 5000+ |
| max_completion_tokens 너무 낮음 | 사고가 답을 차지, 답이 잘림 | 25000+ |
| thinking 출력을 프로덕션에 그대로 | 정보 과부하 + 보안 위험 | 요약 또는 숨김 |
| 모든 사용자에게 thinking 활성 | 단순 질문도 reasoning | flag 기반 활성 |

---

## 8. 체크리스트

- [ ] 작업 유형이 reasoning ON 트리거 (섹션 4.2)에 해당하는가
- [ ] Cascade 패턴으로 가벼운 모델 먼저 시도하는가
- [ ] budget_tokens / reasoning_effort가 작업 매트릭스(섹션 3)와 일치하는가
- [ ] max_completion_tokens가 25K 이상 (사고 공간 확보)
- [ ] thinking/output 비율 모니터링하는가
- [ ] 사용자에게 사고 토큰을 그대로 노출하지 않는가
- [ ] prompt caching과 함께 사용하여 비용 최적화
- [ ] thinking 출력에 시크릿 노출 가능성 점검 (예: 비밀번호 추론 시도)

---

## 9. 참고

- OpenAI Reasoning Guide: <https://platform.openai.com/docs/guides/reasoning>
- Anthropic Extended Thinking: <https://docs.anthropic.com/en/docs/build-with-claude/extended-thinking>
- Cascade 패턴 (FrugalGPT 논문): <https://arxiv.org/abs/2305.05176>
