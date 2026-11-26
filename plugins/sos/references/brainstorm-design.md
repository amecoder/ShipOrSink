# Brainstorm & Design 상세 — Phase 0(BRAINSTORM) + Phase 1(DESIGN)

> [cycle](../skills/cycle/SKILL.md)에서 링크됨. `tdd`/`full` 모드에서만 실행 (`quick` 모드는 이 문서 전체를 스킵한다).

## 목차
- [Step 0: 사전 점검](#step-0-사전-점검)
- [Phase 0: BRAINSTORM (기획 브레인스토밍 → BRIEF.md)](#phase-0-brainstorm-기획-브레인스토밍--briefmd)
- [Phase 1: DESIGN (문서 생성)](#phase-1-design-문서-생성)

---

## Step 0: 사전 점검

```bash
git status -sb && git branch --show-current
```

- **main/master에서 작업 중** → "feature branch에서 작업하세요" 경고 후 중단
- **커밋 안 된 변경** → stash 또는 커밋 제안

### 프로젝트 타입 감지

```bash
if [ -f package.json ]; then echo "RUNTIME:node"; fi
if [ -f pyproject.toml ] || [ -f requirements.txt ]; then echo "RUNTIME:python"; fi
if [ -f build.gradle.kts ] || [ -f pom.xml ]; then echo "RUNTIME:jvm"; fi
if [ -f go.mod ]; then echo "RUNTIME:go"; fi
if [ -f Cargo.toml ]; then echo "RUNTIME:rust"; fi
if [ -f pubspec.yaml ]; then echo "RUNTIME:flutter"; fi

# 테스트 프레임워크 감지
ls jest.config.* vitest.config.* pytest.ini .rspec Cargo.toml 2>/dev/null
ls -d test/ tests/ spec/ __tests__/ e2e/ 2>/dev/null

# 웹 프로젝트 감지 (glob 안전)
rg --files -g '*.tsx' -g '*.vue' -g '*.svelte' src/ templates/ 2>/dev/null | head -1 | grep -q . && echo "WEB:true" || echo "WEB:false"

# 테스트 하네스 상태 감지
# present: 설정 파일 존재 (jest.config, pytest.ini 등)
# partial: 테스트 디렉토리만 있거나 package.json에 test script만 있음
# missing: 테스트 관련 흔적 없음
TEST_HARNESS_STATUS="present"
if ! ls jest.config.* vitest.config.* pytest.ini setup.cfg tox.ini .rspec Cargo.toml 2>/dev/null | grep -q .; then
  if ls -d test/ tests/ spec/ __tests__/ 2>/dev/null | grep -q . \
     || ([ -f package.json ] && grep -q '"test"' package.json 2>/dev/null) \
     || ([ -f pyproject.toml ] && grep -q 'pytest\|unittest' pyproject.toml 2>/dev/null); then
    TEST_HARNESS_STATUS="partial"
  else
    TEST_HARNESS_STATUS="missing"
  fi
fi
echo "TEST_HARNESS:$TEST_HARNESS_STATUS"
```

**TEST_HARNESS=missing일 때**: Phase 1 DESIGN.md에 "Task 0: 테스트 하네스 설치" 태스크를 강제로 포함한다.

**클린 베이스라인 (TEST_HARNESS=present|partial일 때)**: 작업 시작 전 기존 테스트 스위트를 1회 실행해 결과를 STATE.md에 기록한다. **기존 실패가 있으면** 평문 질문: "베이스라인에 실패 N건이 있습니다. 조사 / 무시하고 진행 / 중단?" — 기존 실패와 새 버그를 구분할 수 없는 상태로 시작하지 않는다.

### 문서 디렉토리 생성 + STATE.md 조기 생성

문서 디렉토리를 먼저 만든 뒤, STATE.md를 즉시 생성한다. Phase 0/1 중단 시에도 `--resume`으로 재개 가능하게 한다.

```bash
FEATURE_NAME="$ARGUMENTS에서 추출한 기능명 (영문, kebab-case)"
FEATURE_DIR="docs/features/$(date +%Y-%m-%d)_${FEATURE_NAME}"
mkdir -p "$FEATURE_DIR"
```

**Write `$FEATURE_DIR/STATE.md`:**

```markdown
---
feature: 기능명
feature_dir: docs/features/YYYY-MM-DD_기능명
branch: feat/feature-name
base_commit: <git rev-parse HEAD>
mode: tdd | full
phase: interview
step: start
iteration: 1
retry_count: 0
execution_mode: pending
status: in-progress
regression:
  cmd: ""
  cwd: "."
  env: {}
---
## Progress Log
### Step 0: 사전 점검 → PASS
- 브랜치: feat/feature-name
- 런타임: node|python|...
- 테스트 하네스: present|partial|missing
```

이후 각 Phase/Step 완료 시 STATE.md의 `phase`, `step` 필드를 갱신한다. HANDOFF.md 갱신 규칙은 [SKILL.md의 상태 영속화](../skills/cycle/SKILL.md#상태-영속화)를 따른다.

### `--resume` 처리

`--resume` 플래그가 있으면:
1. `docs/features/`에서 가장 최근 STATE.md를 찾는다
2. **STATE.md 검증**:
   - frontmatter의 `feature`, `feature_dir`, `phase`, `step`, `branch`, `base_commit` 필드가 존재하는가?
   - `branch` 값이 현재 브랜치(`git branch --show-current`)와 일치하는가?
   - `base_commit`이 현재 브랜치 ancestry에 포함되는가? (`git merge-base --is-ancestor $base_commit HEAD`)
   - `feature_dir` 디렉토리가 실제로 존재하는가?
   - 검증 실패 시 → 평문 질문: "STATE.md가 현재 브랜치와 불일치합니다. 새로 시작 / 기존 STATE 사용 / 중단?"
3. `phase`가 `implement` 이상이면 **Phase 0를 건너뛴다**
4. 해당 단계부터 재개한다

**quick 모드 재개**: `docs/features/` 대신 [done-loop.md](done-loop.md#donesh-계약)의 `$DONE_DIR` 을 계산해 `done.sh`·`done.sh.frozen`·`baseline.txt`·(있으면) `STATE.md` 를 읽는다. `done.sh` 나 `done.sh.frozen` 이 없으면 재개하지 않고 묻는다. `STATE.md` 가 없으면 첫 반복부터, 있으면 Done Loop 표 마지막 줄 다음 반복부터 이어 간다.

**기존 문서 자동 감지 (구 `--quick` 플래그 대체)**: `$FEATURE_DIR`(또는 사용자가 지정한 기존 feature 디렉토리)에 BRIEF.md + PLAN.md + SPEC.md + DESIGN.md가 **모두** 존재하면, 다시 인터뷰하지 않고 문서 내용을 그대로 승인된 것으로 간주해 Phase 2로 직행할지 번호 붙인 평문 질문으로 확인한다. 일부만 존재하면 누락된 문서부터 이어서 작성한다 (전체 재작성 아님).

---

## Phase 0: BRAINSTORM (기획 브레인스토밍 → BRIEF.md)

**스킵 조건**: 기존 문서 자동 감지로 전체 스킵 확정, 또는 `--resume`으로 재개 시 STATE.md phase가 `implement` 이상

**목표**: 모호함을 0으로 만들고, 승인된 기획서(BRIEF.md)를 산출한 뒤 Phase 1로 넘어간다.
인터뷰는 최대 3라운드. **각 라운드 전에 `$ARGUMENTS`와 이미 확인된 답변을 재검토**하여 이미 아는 것은 다시 묻지 않는다.

**질문 방식 (superpowers 이식):**
- **모아서 한 번에**: 번호 붙인 평문 질문으로 한 번에, 질문마다 추천 답을 붙여 — 라운드마다 남은 미정 사항을 묶어 묻는다
- **선택지 우선**: 열린 질문보다 구체적 선택지 2-4개 + 추천안(첫 옵션, 근거 포함)을 제시한다
- **아는 것은 묻지 않는다**: `$ARGUMENTS`·코드베이스에서 추론 가능하면 가정으로 제시하고 확인만 받는다

**스코프 과대 감지**: `$ARGUMENTS`가 독립 서브시스템 여러 개를 묘사하면(예: "채팅+파일저장+결제+분석 플랫폼") 세부 질문에 라운드를 쓰지 말고 즉시 지적한다 — 서브프로젝트 분해(무엇이 독립적인가, 어떤 순서로 만들 것인가)를 먼저 합의하고, 첫 서브프로젝트만 이번 사이클로 진행한다. 각 서브프로젝트는 자체 BRIEF→SPEC→PLAN 사이클을 가진다.

### 인터뷰 전: 명확성 평가

`$ARGUMENTS`를 분석해서 다음 항목 중 **불명확한 것**을 체크한다:

```
□ A. 한 문장 정의 — 주어+동사+목적이 명확한가?
□ B. 사용 시나리오 — 누가, 언제, 어떤 입력, 어떤 결과?
□ C. 완료 판정 조건 — 어떻게 검증할 수 있는가? (측정 가능한 결과)
□ D. 이번 범위 외 항목 — 무엇을 이번에 안 하는가?
□ E. 입출력 형태 — 데이터 구조, 타입, API 형태
□ F. 에러/엣지 케이스 — 실패 시 어떻게 되어야 하는가?
□ G. 제약 조건 — 성능, 보안, 호환성
□ H. 타겟과 이유 — 누구를 위한 기능이고, 왜 지금 필요한가?
□ I. 성공 지표 — 배포 후 무엇이 개선되면 성공인가? (측정 가능하면 수치로)
```

**A~D·H가 모두 명확** → Round 1 스킵, 요약 바로 작성 후 승인 게이트
**A~D·H 중 하나라도 불명확** → Round 1 실행
**E~G·I까지 모두 명확** → 인터뷰 전체 스킵, 요약 바로 작성

### Round 1 — 핵심 파악 (A~D·H 불명확 시)

**번호 붙인 평문 질문** — 불명확한 항목을 **한 번에 모아** 묻는다 (질문마다 추천 답 포함):

- **A (한 문장 정의)**: "이 기능을 한 문장으로 표현하면? (주어+동사+목적)"
- **B (사용 시나리오)**: "가장 대표적인 사용 예시를 보여달라. 누가, 언제, 어떤 입력으로, 무슨 결과를 기대하는가?"
- **C (완료 판정 조건)**: "이 기능이 완성됐다는 걸 어떻게 검증할 수 있는가?"
- **D (이번 범위 외)**: "이번에 반드시 안 해도 되는 것은?" — YAGNI 후보를 선택지로 제시
- **H (타겟과 이유)**: "누구를 위한 기능이고, 왜 지금 필요한가?"

Round 1 후 A~D·H가 모두 명확해지면 → 요약으로 바로 이동
여전히 E~G·I 중 불명확한 것이 있으면 → Round 2 실행

### Round 2 — 세부 사항 (E~G·I 불명확 시)

불명확한 항목을 **한 번에 모아**(1회 최대 4문항, 문항당 1주제):

- **E (입출력 형태)**: "데이터의 형태는? 입력으로 무엇이 들어오고, 출력으로 무엇이 나가야 하는가?"
- **F (에러/엣지 케이스)**: "잘못된 입력이나 실패 시 어떻게 되어야 하는가?"
- **G (제약 조건)**: "성능 요건, 보안 요건, 기존 코드와의 호환성 등 지켜야 할 제약이 있는가?"
- **I (성공 지표)**: "배포 후 무엇이 개선되면 성공인가? 측정 방법은?"

Round 2 후 모두 명확해지면 → 요약으로 이동
여전히 불명확하면 → Round 3 실행

### Round 3 — 최종 확인 (여전히 불명확할 때만)

남은 불명확 항목에 대해 마지막 질문.
Round 3 후에도 불명확하면 → **"가정" 목록으로 기록하고 진행 여부를 묻는다**

**중단 선택 시** → Phase 0 상태를 메모하고 완전히 멈춘다.

### Phase 0 GATE — 기획 요약 확인 + BRIEF.md 승인

수집한 내용을 **인라인으로 요약**하여 보여준다:

```
=== 기획 요약 ===

기능: [한 문장]
타겟/이유: [누구를 위해, 왜 지금]
성공 지표: [배포 후 무엇이 개선되면 성공]

사용 시나리오:
  - [사용자] → [트리거] → [결과]

완료 판정 조건 (Acceptance Criteria 후보):
  - [ ] ...

이번 범위 외 (YAGNI):
  - ...

입출력 형태:
  - 입력: ...
  - 출력: ...

가정 (불명확하여 결정한 것):
  - ...

=================
```

**평문 질문**: "위 기획 요약이 의도한 내용과 일치합니까?"
- **일치** → BRIEF.md 작성 후 Phase 1 진행
- **수정 있음** → 수정 내용 반영 후 요약 재작성 → 재확인
- **근본적으로 다름** → Round 1부터 재시작
- **중단** → 완전히 멈추고 대기

**승인 후 Write `$FEATURE_DIR/BRIEF.md`** (기획서 — Why 계층의 독립 산출물):

```markdown
---
feature: 기능명
created: YYYY-MM-DD
status: approved
---

# 기능명 — 기획서 (BRIEF)

## 문제 정의
(현재 무엇이 불편하거나 불가능한가)

## 타겟과 이유
(누구를 위해, 왜 지금)

## 성공 지표
(측정 가능한 기준 — 배포 후 무엇이 개선되면 성공)

## 사용 시나리오
- [사용자] → [트리거] → [결과]

## 완료 판정 조건
- ...

## 이번 범위 외 (YAGNI)
- ...

## 가정
- ...
```

STATE.md 갱신: `step: brief → PASS`

---

## Phase 1: DESIGN (문서 생성)

**기존 문서 자동 감지로 스킵된 경우에만 생략** — 없으면 항상 실행.

**진행 방식 (Incremental Validation)**: 문서를 한꺼번에 쓰고 끝내지 않는다. PLAN → SPEC → DESIGN 순서로, **각 문서 작성 직후 핵심 요약(복잡도에 비례해 몇 문장~300단어)을 보여주고 승인받은 뒤** 다음 문서로 진행한다. 각 승인 시 YAGNI 점검("이거 이번에 정말 필요한가?")을 함께 수행한다.

### Step 1a: 설계 대안 탐색 (Explore Alternatives)

PLAN.md를 쓰기 전에 **기술 접근법 2-3개를 트레이드오프와 함께 제시**하고 사용자가 선택하게 한다.

1. 코드베이스 탐색(`rg`, `ast-grep`)으로 실현 가능한 접근법 2-3개 도출
2. **번호 붙인 평문 질문**으로 제시 — 각 옵션에 구현 비용·리스크·확장성 트레이드오프 명시, **추천안을 첫 옵션으로** 배치하고 근거 포함
3. 자명한 경우(현실적 접근법이 1개뿐)는 "대안 없음 — [접근] 단일안, 이유: ..."를 한 줄로 보고하고 진행

선택된 접근이 PLAN.md의 "기술 접근" 섹션이 된다. 기각된 대안은 "검토한 대안"에 한 줄씩 기록한다 (재논의 방지).

### Step 1: Plan → PLAN.md

Phase 0에서 확정된 요건 + Step 1a에서 선택된 접근을 기반으로 구현 계획을 수립한다.

1. BRIEF.md + Step 1a 선택 기반
2. `rg`, `ast-grep`으로 관련 파일 탐색
3. **`docs/solutions/` 검색 (존재 시)**: 매번 fresh하게 glob하고(인덱스 캐시 금지 — 방금 쓴 학습을 놓친다), frontmatter의 `applies_when`·`tags`가 이번 기능과 겹치는 문서를 읽어 계획에 반영한다
4. 영향 범위 분석

**Write `$FEATURE_DIR/PLAN.md`:**

```markdown
---
feature: 기능명
created: YYYY-MM-DD
status: draft
---

# 기능명 — 구현 계획

## 배경
(왜 이 기능이 필요한가)

## 목표
(Phase 0 한 문장 정의)

## 범위
### 포함
- ...
### 제외 (Phase 0 합의 기준)
- ...

## 기술 접근
(Step 1a에서 선택된 접근 + 선택 근거)

### 검토한 대안 (기각)
- 대안 B: ... — 기각 사유

## 영향 범위
### 수정 파일
- `path/to/file` — 변경 내용
### 신규 파일
- `path/to/new` — 목적

## 리스크
- ...

## 가정 사항
(Phase 0에서 불명확하여 가정으로 결정한 것들)
- ...
```

> **[섹션 승인 — PLAN]** PLAN.md 핵심(기술 접근·영향 범위·리스크)을 복잡도에 비례한 분량으로 요약 제시.
> 평문 질문: "계획이 맞습니까?" — 수정 요청 시 반영 후 재확인, 승인 후 Step 2 진행.

### Step 2: Spec → SPEC.md

PLAN.md + BRIEF.md 완료 판정 조건을 기반으로 상세 명세를 작성한다.
**BRIEF.md의 완료 판정 조건이 모두 AC로 커버되어야 한다.**

**Write `$FEATURE_DIR/SPEC.md`:**

```markdown
---
feature: 기능명
created: YYYY-MM-DD
status: draft
---

# 기능명 — 기능 명세

## 기능 요구사항
- FR-01: ...

## 비기능 요구사항
- NFR-01: ...

## Acceptance Criteria
(BRIEF.md 완료 판정 조건에서 도출)
- [ ] AC-01: (검증 가능한 구체적 조건)
- [ ] AC-02: ...

## Invariants (불변 조건)
(어떤 입력·경로에서도 위반되면 안 되는 조건 — 적대 게이트 ⓐⓑ의 공격 대상)
- INV-01: ...

## 엣지 케이스
(Phase 0 Round 2에서 도출)
- EC-01: ...

## 에러 시나리오
- ERR-01: ...

## 가정 사항
(Phase 0에서 불명확하여 결정한 것 — 이후 발견 시 재협의 필요)
- ...
```

**AC 작성 규칙:**
- "잘 작동한다" → "200 OK + JWT 토큰 반환"
- 테스트로 변환 가능해야 함
- 엣지 케이스도 AC에 포함

**Invariant 작성 규칙:**
- AC는 "이 입력이면 이 출력"(사례), Invariant는 "언제나 참"(전칭) — 예: "잔액은 어떤 연산 후에도 음수가 되지 않는다"
- 최소 1개 이상. 도출이 어려우면 데이터 무결성·멱등성·권한 경계에서 찾는다

> **[섹션 승인 — SPEC]** AC + Invariants + 엣지 케이스 목록을 제시. 명령으로 확인할 수 없는 AC 가 있으면 "수동 확인(MANUAL)으로 둘지"를 같은 질문에 넣는다 — 이 분류는 사용자만 정한다.
> 평문 질문: "이 명세로 확정합니까?" — 수정 요청 시 반영 후 재확인, 승인 후 Step 3 진행.

### Step 3: TDD Design → DESIGN.md

**Write `$FEATURE_DIR/DESIGN.md`:**

```markdown
---
feature: 기능명
created: YYYY-MM-DD
status: draft
---

# 기능명 — TDD 설계 & 아키텍처

## 아키텍처
(Excalidraw 다이어그램 — `excalidraw` 스킬, `![설명](assets/<이름>.svg)`)

## 인터페이스 정의
(핵심 함수 시그니처, 타입, API 스키마 — Phase 0 입출력 형태 기반)

## 테스트 계획

### Unit Tests
| ID | 테스트 명 | 대상 | AC 매핑 | 기대 결과 |
|----|----------|------|---------|----------|

### Integration Tests
| ID | 테스트 명 | 범위 | AC 매핑 |
|----|----------|------|---------|

### E2E Tests (웹 프로젝트만)
| ID | 시나리오 | 사용자 플로우 | AC 매핑 |
|----|---------|-------------|---------|

## 태스크 분해 (SDD 모드용)
(각 태스크는 독립 실행 가능한 단위)

### Task 1: [컴포넌트명]
- **파일**: `path/to/file`
- **AC 매핑**: AC-01, AC-02
- **의존성**: 없음 | Task N 완료 후
- **복잡도**: low | medium | high

## 파일 구조
(신규/수정 파일 트리)

## 구현 순서
1. 테스트 파일 생성 (RED)
2. 핵심 로직 구현 (GREEN)
3. 리팩터링 (REFACTOR)
```

### Step 3b: 완료 판정 스크립트 → done.sh

DESIGN.md 를 쓴 직후, 승인된 AC 를 하나에 `check` 한 줄씩 `$FEATURE_DIR/done.sh` 로 옮긴다. 테스트 이름은 DESIGN.md 테스트 계획의 것을 쓴다. 지금 돌리면 테스트가 없어 FAIL 이 나는 것이 당연하므로, 기준선 실행과 동결은 Phase 2 RED 커밋 직후에 한다. 문서만 요청한 실행이면 이 단계를 건너뛴다. 계약·예시: [done-loop.md](done-loop.md#donesh-계약)

> **[섹션 승인 — DESIGN]** 테스트 계획 요약(AC 매핑 수) + 태스크 분해 목록 + `done.sh` 전문을 제시.
> 평문 질문: "이 설계로 진행합니까?" — 수정 요청 시 반영 후 재확인, 승인 후 `cp done.sh done.sh.approved` 하고 셀프리뷰 진행.

### Spec 셀프리뷰 (Phase 1 마무리)

3개 문서를 모두 작성한 뒤, 직접 아래 항목을 점검한다:

1. **플레이스홀더 스캔**: "TBD", "TODO", 미완성 섹션, 모호한 요구사항이 있는가? → 즉시 수정
2. **내부 일관성**: PLAN↔SPEC↔DESIGN 사이에 모순은 없는가? 아키텍처가 기능 명세와 일치하는가?
3. **범위 점검**: 단일 구현 사이클로 소화 가능한 크기인가? 아니면 분해가 필요한가?
4. **모호성 점검**: 두 가지로 해석될 수 있는 요구사항이 있는가? → 하나로 확정
5. **AC 커버리지**: SPEC.md의 모든 AC가 DESIGN.md의 테스트 계획에 매핑되어 있고, `done.sh` 에 `check AC-xx` 또는 승인된 `MANUAL AC-xx` 한 줄씩 있는가? (`diff <(grep -oE '^- \[[ x]\] AC-[0-9]+' SPEC.md | grep -oE 'AC-[0-9]+' | sort -u) <(grep -oE '^(check|echo "MANUAL) AC-[0-9]+' done.sh | grep -oE 'AC-[0-9]+' | sort -u)` 출력이 비어야 한다)
6. **Invariant 커버리지**: SPEC.md의 모든 Invariant를 검증하는 테스트가 계획에 있는가?

발견된 문제는 즉시 인라인 수정. 별도 리뷰 라운드 불필요.
셀프리뷰는 기계적 결함(플레이스홀더·불일치)용이다 — 설계 타당성 검증은 적대 게이트 ⓐ가 담당한다.

### 리뷰 결과 수신 규율 (게이트 ⓐⓑ·SDD 리뷰·quick 모드 Co-Review 공통)

리뷰 피드백은 따를 명령이 아니라 **평가할 주장**이다. 리뷰 결과를 받으면:

1. **전체 완독 후 반응** — 지적별 즉흥 반응 금지. 불명확한 지적이 있으면 부분 구현 금지, 먼저 명확화한다 (지적들은 서로 연관될 수 있다)
2. **대조 검증** — 각 지적을 실제 코드베이스·문서와 대조해 타당성을 확인한다 (리뷰어는 전체 맥락이 없을 수 있다)
3. **수행적 동의 금지** — "좋은 지적입니다"·"맞습니다!" 류 금지. **검증 소견(타당 / 반박 / 검증불가 + 근거)**만 제시한다
4. **틀린 지적엔 기술적 반박** — 기존 테스트·코드·호환성 근거를 제시. 반박이 틀렸음이 확인되면 사실만 정정하고 진행한다
5. **수용분은 한 건씩** 구현하고 각각 테스트한다

**리뷰어 프롬프트 작성 시 편향 방지:**
- 리뷰어에게 **사전 판정 지시 금지** — "이건 flag하지 마라", "기껏해야 Minor" 같은 문구가 프롬프트에 들어가면 독립 리뷰의 가치가 사라진다. false positive라 생각되면 리뷰어가 지적하게 두고 수신 단계에서 반박한다
- 리뷰어에게 명시할 것: **구현자 리포트·문서 내 변명("YAGNI라서 뺐다" 등)은 검증 안 된 자기 채점** — 심각도를 낮추는 근거가 되지 못한다

### 적대 게이트 ⓐ — 독립 모델 문서 공격

**리뷰를 요청했을 때(`--review` 또는 요청 문장에 "리뷰")만 실행한다 — 기본은 건너뛴다**. 셀프리뷰 통과 후 실행한다. 결과 처리는 위 "리뷰 결과 수신 규율"을 따른다.

동종 모델 셀프리뷰는 같은 오류에 수렴한다(popularity trap) — 승인 전 문서를 **독립 모델이 공격**한다.

1. **codex-advisor**에 위임 (`codex exec --profile deep-review`, read-only — 또는 `/codex:adversarial-review` 커맨드):
   - 입력: BRIEF.md, PLAN.md, SPEC.md, DESIGN.md 경로
   - 리뷰 지침 (프롬프트에 포함):
     - **pass/fail 판정 금지** — 지적마다 "재작성 명령 + 설계 근거 요구" 형식 (이진 게이트는 국소 패치만 유발)
     - SPEC의 **Invariants·AC와 설계 간 구조적 모순**을 최우선 공격
     - 누락된 요구사항·엣지 케이스·암묵적 가정을 추론해 지적
     - 심각도 표기: **Major**(설계 결함·모순·요구 누락) / **Minor**(개선 여지)
2. **결과 처리 ("적당히 적대적" 수위 조절)**:
   - **Major** → 각 지적을 문서·코드베이스와 대조 검증한 뒤, **검증 소견(타당/반박/검증불가 + 근거)을 붙여** 지적별 평문 질문: "수용(문서 수정) / 기각(사유 기록)" — 최종 결정은 항상 사용자
   - 수용분 반영 후 **재리뷰는 최대 1회** (무한 비평 루프 방지)
   - **Minor** → STATE.md Progress Log에 메모만 (구현 중 참고)
   - 기각 사유는 STATE.md에 기록 (같은 지적 재론 방지)
3. **codex 미가용 시** (미설치·에러): `code-reviewer` 서브에이전트로 폴백하되, 동종 모델 한계를 보고에 명시

STATE.md 갱신: `step: adversarial_a → PASS`, 수용/기각 목록 기록

### Phase 1 GATE

```
BRIEF.md 존재? && PLAN.md 존재? && SPEC.md에 AC 1개 이상 + Invariant 1개 이상?
&& DESIGN.md에 테스트 계획 있음? && done.sh 작성·AC 대조 통과? (문서만 요청이면 해당 없음 — 기준선·동결은 Phase 2 RED 커밋 직후) && 셀프리뷰 통과?
&& 적대 게이트 ⓐ 처리 완료? (리뷰 요청이 없었으면 해당 없음)
  → Yes: Phase 2 진행
  → No: 누락된 문서 생성 후 재확인
```

### STATE.md 갱신 (Phase 1 완료)

Step 0에서 생성된 STATE.md를 갱신한다:

```yaml
phase: implement
step: red
execution_mode: inline | sdd  # 사용자 선택 반영
```

**Acceptance Criteria Status** 섹션을 추가: SPEC.md에서 AC 목록을 복사하여 모두 미체크. 이후 체크는 `done.sh` 출력을 옮겨 적을 때만 한다.
**Done Loop** 섹션을 빈 표로 추가: Phase 2 RED 커밋 직후의 기준선 `done.sh` 결과가 iter 0 이 된다 ([done-loop.md](done-loop.md#루프와-멈춤-조건) 형식).
**Test Status** 섹션을 추가: Unit 0/N, Coverage 0%.
**Progress Log**에 Phase 0/1 결과를 기록.

`tdd` 모드에서 `--full`(전체 사이클) 없이 문서만 요청받았으면 여기서 종료.

> **[확인 게이트 — Phase 2 시작 · `full` 모드만]** 평문 질문: "Phase 1(문서 생성) 완료. Phase 2(TDD 구현)를 시작할까요? 실행 모드: Inline(기본) / SDD(서브에이전트)"

**`full` 모드 추가 게이트**: 위 게이트 외에도 Round 1/2/3 인터뷰의 각 질문 직후, PLAN/SPEC/DESIGN 섹션 승인 게이트 각각(이미 위에 명시됨)이 전부 개별 평문 질문으로 실행되어야 한다 — 여러 섹션을 한 번에 몰아 승인받지 않는다. `tdd` 모드는 문서 3종을 한 번에 승인받는 축약도 허용하지만 `full` 모드는 허용하지 않는다.

다음 단계: [implement-tdd.md](implement-tdd.md)
