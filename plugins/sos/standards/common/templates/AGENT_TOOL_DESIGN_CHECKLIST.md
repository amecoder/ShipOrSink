# Agent-Computer Interface (ACI) Design Checklist

에이전트가 사용할 도구를 설계할 때 적용. Anthropic "Building Effective Agents"의 핵심: **에이전트 실패의 가장 큰 원인은 모델 능력이 아니라 도구 인터페이스 품질**이다.

## 1. 도구 명세 (Tool Spec) 표준

### 1.1 도구 이름 (name)
- 동사로 시작: `read_file`, `search_code`, `run_tests` (좋음)
- 명사 단독: `file`, `code`, `tests` (나쁨)
- 30자 이내, snake_case
- 같은 동작은 단일 도구로 통합 (예: `read_file` 하나, 별도 `read_text_file`/`read_binary_file` 분리 X)

### 1.2 도구 설명 (description)
설명은 **에이전트가 읽는 매뉴얼**이다. 다음을 모두 포함:

| 항목 | 필수 | 예시 |
|------|------|------|
| 1줄 요약 | 필수 | "Read a file from the workspace" |
| 사용 시점 | 필수 | "Use when you need to inspect existing code before editing" |
| **사용하지 말아야 할 때** | 필수 | "Do NOT use for binary files >10MB; use `head_file` instead" |
| 인자 의미 | 필수 | "path: absolute path under /workspace, no `..` allowed" |
| 반환값 형식 | 필수 | "Returns {content: str, line_count: int, truncated: bool}" |
| 실패 모드 | 필수 | "Returns {error: 'not_found' \| 'too_large' \| 'permission_denied'}" |
| 비용/지연 힌트 | 권장 | "Latency: <100ms for files <1MB" |
| 예시 호출 1-2개 | 권장 | `read_file(path="/workspace/src/main.py")` |

**나쁜 예** (실제 흔한 패턴):
```json
{
  "name": "read",
  "description": "Reads a file"
}
```

**좋은 예**:
```json
{
  "name": "read_file",
  "description": "Read a UTF-8 text file from /workspace and return its contents.\n\nUse this when you need to inspect existing code before editing. Always read a file before using `edit_file` on it.\n\nDo NOT use for:\n- Binary files >10MB (use `head_file` or skip)\n- Files outside /workspace (returns permission_denied)\n- Reading the same file repeatedly in a session (cache the result)\n\nLatency: <100ms for typical source files.",
  "input_schema": {
    "type": "object",
    "required": ["path"],
    "properties": {
      "path": {
        "type": "string",
        "description": "Absolute path under /workspace. Path traversal (..) is rejected.",
        "examples": ["/workspace/src/main.py"]
      },
      "max_lines": {
        "type": "integer",
        "description": "Optional limit; full file by default.",
        "default": null
      }
    }
  }
}
```

## 2. 입력 스키마 (input_schema)

- JSON Schema 사용 (OpenAI strict mode 호환)
- `required` 필드 명시
- 각 필드에 `description` 필수 (이름만으로 추론 금지)
- enum / pattern으로 제약 명시 (자유 텍스트 최소화)
- 큰 페이로드는 청크/페이징 (한 번에 1MB 초과 금지)

## 3. 반환값 (Rich Context)

도구 응답은 단순 success/fail이 아니라 **에이전트가 다음 행동을 결정할 수 있는 정보** 포함.

### 3.1 성공 케이스
```json
{
  "ok": true,
  "data": { "content": "...", "line_count": 42 },
  "metadata": {
    "truncated": false,
    "encoding": "utf-8",
    "size_bytes": 1024
  },
  "next_actions_hint": [
    "If you want to edit, call `edit_file` with the same path",
    "If file is too large to analyze whole, use `search_in_file`"
  ]
}
```

### 3.2 실패 케이스 (정보가 풍부할수록 자가 회복 가능)
```json
{
  "ok": false,
  "error": {
    "code": "FILE_TOO_LARGE",
    "message": "File is 50MB, exceeds 10MB limit",
    "actual_size_bytes": 52428800,
    "limit_bytes": 10485760,
    "recovery": [
      "Use `head_file(path, n=1000)` to read first 1000 lines",
      "Use `search_in_file(path, pattern)` to find specific content"
    ]
  }
}
```

**나쁜 예**:
```
Error: File too large
```

## 4. 도구 명명 규칙 — 충돌 방지

| 카테고리 | 동사 | 예시 |
|----------|------|------|
| 조회 | read, get, search, list, show | `read_file`, `search_code` |
| 변경 | edit, update, write, create, delete | `edit_file`, `create_file` |
| 실행 | run, execute, invoke | `run_tests`, `run_lint` |
| 분석 | analyze, validate, check | `analyze_diff`, `validate_schema` |
| 외부 | fetch, send, post | `fetch_url`, `send_notification` |

**금지**:
- 같은 동작에 여러 이름 (`get_file` vs `read_file` 동시 노출)
- 부정형 이름 (`not_run_tests`)
- 약어 (`rd_file`, `exec`)

## 5. 도구 개수 — 토큰 예산

- 에이전트 한 세션에 **30개 이하** 권장 (Anthropic 가이드)
- 도구 설명 총 토큰: **2K 미만** (모든 도구 합산)
- 도구가 많아지면 검색 메타 도구 (`list_available_tools`) + 동적 로딩

## 6. 부작용 명시 (Idempotency)

| 도구 | 부작용 | Idempotent? | 표기 |
|------|--------|-------------|------|
| `read_file` | 없음 | Yes | "side_effects": "none" |
| `run_tests` | 일시적 (테스트 결과 캐시) | Yes | "side_effects": "ephemeral" |
| `edit_file` | 영구 (파일 변경) | No (다른 입력으로 다른 결과) | "side_effects": "persistent" |
| `git_commit` | 영구 (commit 생성) | No | "side_effects": "persistent" |
| `deploy` | 영구 + 외부 영향 | No | "side_effects": "external" |

부작용이 있는 도구는 description에 명시 + human approval 게이트 고려.

## 7. 도구 그룹화 (Capability Bundles)

도구를 역할별로 묶고 에이전트별로 다른 번들 노출:

```python
TOOL_BUNDLES = {
    "explorer": ["read_file", "list_dir", "search_code", "git_status"],  # 읽기만
    "editor": ["read_file", "edit_file", "create_file", "delete_file", "run_lint"],
    "tester": ["read_file", "run_tests", "analyze_coverage"],
    "deployer": ["read_file", "git_status", "create_pr", "deploy"],  # 위험 도구 포함
}
```

에이전트는 자신의 역할에 필요한 번들만 받음 (최소 권한 원칙).

## 8. 로깅 / 트레이스 (관측 가능성)

각 도구 호출에 다음 메타 자동 부착:

- `tool_call_id` (UUID)
- `parent_tool_call_id` (체인일 때)
- `agent_id`, `session_id`, `model`
- `latency_ms`, `tokens_consumed`, `cost_usd`
- `outcome: ok | error | timeout | denied`

이 데이터로 **도구별 실패율, 평균 지연, 비용 분석**이 가능해야 한다.

## 9. ACI 검증 체크리스트 (도구 추가/수정 시)

- [ ] 도구 이름이 동사로 시작하고 30자 이내인가
- [ ] description에 "사용 시점" + "사용하지 말아야 할 때"가 명시되었는가
- [ ] 인자별 description이 모두 채워져 있는가 (이름만으로 추론 X)
- [ ] 반환값이 rich context인가 (단순 string 아님)
- [ ] 실패 케이스에 `error.code` + `recovery` 힌트가 있는가
- [ ] 부작용(side_effects) 분류가 명시되었는가
- [ ] 같은 카테고리의 다른 도구와 명명이 일관되는가
- [ ] 도구 묶음에서 토큰 예산 2K를 초과하지 않는가
- [ ] 위험 등급(L0~L4) 분류가 표시되었는가 (Tool Sandboxing 참조)
- [ ] 로깅 메타가 자동 부착되는가
- [ ] eval 셋에 이 도구 사용 시나리오가 추가되었는가

## 10. 안티패턴

- [ANTI] description이 한 줄 ("Reads a file")
- [ANTI] 반환값이 raw string (구조 없음)
- [ANTI] 에러가 "Error" 또는 throw (recovery 정보 없음)
- [ANTI] 같은 동작을 여러 도구로 분산
- [ANTI] 모든 에이전트에 모든 도구 노출
- [ANTI] 도구 설명에 prompt injection 가능성 (악성 MCP 서버)
- [ANTI] 인자가 자유 텍스트만 (enum/pattern 없음)

## 11. 참고

- Anthropic "Building Effective Agents" (2024.12): <https://www.anthropic.com/research/building-effective-agents>
- Anthropic Tool Use 가이드: <https://docs.anthropic.com/en/docs/build-with-claude/tool-use/overview>
- OpenAI Function Calling: <https://platform.openai.com/docs/guides/function-calling>
- MCP 사양: <https://modelcontextprotocol.io/>
