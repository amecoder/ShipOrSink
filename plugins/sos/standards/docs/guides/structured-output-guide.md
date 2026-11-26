# Structured Output 가이드

> **최종 수정**: 2026-05-01
> **대상**: LLM에서 JSON / 구조화된 데이터를 안정적으로 받아야 하는 모든 코드 에이전트, RAG, 분류기, 파싱기
> **목적**: AI 출력 스키마와 코드 타입을 단일 소스로 동기화하여 형식 오류 0% 보장

---

## 1. 왜 Structured Output인가

LLM 출력을 자유 텍스트로 받고 정규식/JSON.parse로 파싱하면 다음이 발생:

- 약 5-10% 호출에서 형식 오류 (괄호 누락, 잘못된 escape, trailing comma)
- 누락된 필드 / 추가된 필드
- 타입 불일치 (`"true"` vs `true`)
- 파싱 실패 시 재시도 로직 복잡

**해결**: API 레벨에서 JSON Schema를 강제 → 형식 오류 0%, 코드 타입과 자동 동기화.

---

## 2. OpenAI — Structured Outputs `strict: true`

### 2.1 기본 사용

```python
from openai import OpenAI
from pydantic import BaseModel

client = OpenAI()


class CodeReview(BaseModel):
    severity: str  # "blocker" | "major" | "minor" | "info"
    file_path: str
    line: int
    message: str
    suggestion: str | None = None


response = client.chat.completions.parse(
    model="gpt-5",
    messages=[
        {"role": "developer", "content": "Review the code and report issues."},
        {"role": "user", "content": code_snippet},
    ],
    response_format=CodeReview,  # Pydantic 모델 직접 전달
)

review: CodeReview = response.choices[0].message.parsed
print(review.severity)  # 타입 안전, 자동완성
```

### 2.2 `strict: true` JSON Schema 직접 사용

```python
schema = {
    "type": "object",
    "properties": {
        "severity": {"type": "string", "enum": ["blocker", "major", "minor", "info"]},
        "file_path": {"type": "string"},
        "line": {"type": "integer"},
        "message": {"type": "string"},
    },
    "required": ["severity", "file_path", "line", "message"],
    "additionalProperties": False,
}

response = client.chat.completions.create(
    model="gpt-5",
    messages=[...],
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "code_review",
            "strict": True,  # 핵심: 토큰 단위 schema 강제
            "schema": schema,
        },
    },
)
```

`strict: true`는 **토큰 생성 단계에서** schema 위반 토큰을 차단. 형식 오류 발생 불가능 (모델이 schema에 없는 키를 생성하려 해도 거부됨).

### 2.3 Function Calling과 결합

```python
tools = [
    {
        "type": "function",
        "function": {
            "name": "report_issue",
            "description": "Report a code review issue",
            "strict": True,  # function 인자도 strict
            "parameters": schema,
        },
    },
]
```

---

## 3. Anthropic Claude — Tool Use 기반

Anthropic은 명시적 `response_format` 대신 **tool_use**를 사용한다.

### 3.1 단일 도구로 JSON 강제

```python
from anthropic import Anthropic

client = Anthropic()

response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=1024,
    tools=[
        {
            "name": "report_review",
            "description": "Submit the code review findings as structured data",
            "input_schema": {
                "type": "object",
                "properties": {
                    "severity": {"type": "string", "enum": ["blocker", "major", "minor", "info"]},
                    "file_path": {"type": "string"},
                    "line": {"type": "integer"},
                    "message": {"type": "string"},
                },
                "required": ["severity", "file_path", "line", "message"],
            },
        }
    ],
    tool_choice={"type": "tool", "name": "report_review"},  # 강제 호출
    messages=[{"role": "user", "content": code_snippet}],
)

# tool_use 블록에서 추출
for block in response.content:
    if block.type == "tool_use" and block.name == "report_review":
        review = block.input  # dict, schema 보장됨
```

### 3.2 Pydantic ↔ JSON Schema 자동 변환

```python
from pydantic import BaseModel


class CodeReview(BaseModel):
    severity: str
    file_path: str
    line: int
    message: str


def to_anthropic_tool(model: type[BaseModel], description: str) -> dict:
    return {
        "name": model.__name__.lower(),
        "description": description,
        "input_schema": model.model_json_schema(),
    }


tools = [to_anthropic_tool(CodeReview, "Submit code review")]
```

---

## 4. 코드 타입 ↔ AI 스키마 동기화

핵심 원칙: **스키마는 코드에 한 번만 정의**, AI 호출과 응답 검증 모두 같은 정의 사용.

### 4.1 Python — Pydantic

```python
# schemas.py — 단일 소스
from pydantic import BaseModel, Field


class FileEdit(BaseModel):
    """LLM이 제안하는 파일 수정 단위."""
    path: str = Field(description="Absolute path under /workspace")
    old_text: str = Field(description="Exact text to replace")
    new_text: str = Field(description="Replacement text")
    reason: str = Field(description="Why this edit", max_length=200)


class EditPlan(BaseModel):
    """여러 파일 수정 계획."""
    edits: list[FileEdit]
    summary: str


# llm_call.py — AI 호출
response = openai.chat.completions.parse(
    model="gpt-5",
    messages=[...],
    response_format=EditPlan,
)
plan: EditPlan = response.choices[0].message.parsed

# applier.py — 같은 타입을 함수 인자로 사용
def apply_edits(plan: EditPlan) -> None:
    for edit in plan.edits:
        ...
```

### 4.2 TypeScript — Zod

```typescript
// schemas.ts — 단일 소스
import { z } from "zod";

export const FileEdit = z.object({
  path: z.string().describe("Absolute path under /workspace"),
  old_text: z.string().describe("Exact text to replace"),
  new_text: z.string().describe("Replacement text"),
  reason: z.string().max(200).describe("Why this edit"),
});

export const EditPlan = z.object({
  edits: z.array(FileEdit),
  summary: z.string(),
});

export type EditPlan = z.infer<typeof EditPlan>;

// llm_call.ts
import { zodResponseFormat } from "openai/helpers/zod";

const response = await openai.chat.completions.parse({
  model: "gpt-5",
  messages: [...],
  response_format: zodResponseFormat(EditPlan, "edit_plan"),
});

const plan: EditPlan = response.choices[0].message.parsed!;
```

---

## 5. 스키마 설계 패턴

### 5.1 enum으로 자유 텍스트 최소화

```python
# WRONG: 자유 문자열 → 일관성 없음
severity: str

# RIGHT: enum
class Severity(str, Enum):
    BLOCKER = "blocker"
    MAJOR = "major"
    MINOR = "minor"
    INFO = "info"
```

### 5.2 description으로 의미 전달

```python
# Pydantic Field description은 LLM 프롬프트에 포함됨
line: int = Field(description="Line number (1-indexed). Use 0 if file-level issue.")
```

### 5.3 Discriminated Union (대안 표현)

```python
class FileEditAction(BaseModel):
    type: Literal["edit"]
    path: str
    old: str
    new: str

class FileCreateAction(BaseModel):
    type: Literal["create"]
    path: str
    content: str

class FileDeleteAction(BaseModel):
    type: Literal["delete"]
    path: str


Action = FileEditAction | FileCreateAction | FileDeleteAction


class Plan(BaseModel):
    actions: list[Action]
```

OpenAI strict 모드와 Claude tool_use 모두 지원.

### 5.4 nullable / optional 표현

```python
# WRONG: optional이 모호 — strict 모드에서 거부됨
suggestion: str | None = None

# RIGHT: optional은 schema에서 명시 또는 default 사용
suggestion: str = Field(default="")
```

OpenAI strict 모드는 `additionalProperties: false` + `required: ["all_keys"]` 강제. Optional은 `default` 사용 또는 nullable 명시.

### 5.5 길이/범위 제약

```python
class Issue(BaseModel):
    severity: Severity
    line: int = Field(ge=0, le=100_000)
    message: str = Field(min_length=10, max_length=500)
    tags: list[str] = Field(max_length=5)
```

---

## 6. 검증 + 자가 회복

API 레벨 strict이라도 비즈니스 검증은 별도 필요:

```python
def review_code(snippet: str, max_retries: int = 2) -> CodeReview:
    for attempt in range(max_retries + 1):
        try:
            response = openai.chat.completions.parse(
                model="gpt-5",
                messages=[...],
                response_format=CodeReview,
            )
            review = response.choices[0].message.parsed

            # 비즈니스 검증
            if review.line < 0:
                raise ValueError(f"Invalid line: {review.line}")
            if not review.file_path.startswith("/workspace"):
                raise ValueError(f"Out of scope: {review.file_path}")

            return review
        except (ValidationError, ValueError) as e:
            if attempt == max_retries:
                raise
            # 에러를 다음 호출에 피드백
            messages.append({
                "role": "developer",
                "content": f"Previous response failed validation: {e}. Retry with corrected output.",
            })
```

---

## 7. 안티패턴

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| `json.loads(llm_output)` | 5-10% 실패 | strict 모드 사용 |
| 정규식으로 JSON 추출 | 깨지기 쉬움 | API 강제 |
| 매 코드별 별도 schema 정의 | 동기화 안 됨 | Pydantic/Zod 단일 소스 |
| description 누락 | 모델이 의미 추측 | Field(description=...) 필수 |
| 자유 텍스트 enum | 불일치 | Literal / Enum |
| Optional 남용 | strict 모드 거부 | default 또는 명시적 nullable |
| API 레벨만 신뢰 | 비즈니스 룰 위반 가능 | 추가 검증 + 재시도 |

---

## 8. 체크리스트

- [ ] 출력 스키마가 코드의 타입과 단일 소스인가 (Pydantic / Zod)
- [ ] OpenAI 호출 시 `strict: true` 또는 `parse()` 사용
- [ ] Anthropic 호출 시 `tool_use` + `tool_choice` 강제
- [ ] enum / Literal로 자유 텍스트 최소화
- [ ] 모든 필드에 `description` 작성
- [ ] strict 모드 위반 가능 패턴 (Optional, additionalProperties) 점검
- [ ] 비즈니스 검증 레이어 추가 (스키마는 형식만 보장)
- [ ] 검증 실패 시 자가 회복 (max_retries 2회)
- [ ] Eval 셋에 schema edge case (긴 문자열, 빈 배열, enum 경계) 포함

---

## 9. 참고

- OpenAI Structured Outputs: <https://platform.openai.com/docs/guides/structured-outputs>
- Anthropic Tool Use: <https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview>
- Pydantic: <https://docs.pydantic.dev/latest/>
- Zod: <https://zod.dev/>
- Instructor (Pydantic + 다중 LLM): <https://github.com/jxnl/instructor>
