# Quick 모드 상세 — 구현→리뷰→QA→PR 자동 루프

> [cycle](../skills/cycle/SKILL.md)에서 링크됨. `quick` 모드(구 `/auto-build`) 전용. Brief/Plan/Spec/Design 문서화를 생략하고 구현부터 바로 시작한다. 게이트는 최소화하되, 모든 모드 공통인 두 하드 게이트(PR 생성 직전 적대 리뷰, 머지 직전 테스트 통과)는 그대로 유지한다.

## 목차
- [전제 조건](#전제-조건)
- [실행 흐름](#실행-흐름)
- [Step 0: 사전 점검](#step-0-사전-점검)
- [Step 1: Build (구현)](#step-1-build-구현)
- [Step 2: Co-Review (Claude + Codex 교차 리뷰)](#step-2-co-review-claude--codex-교차-리뷰)
- [Step 3: Test/QA](#step-3-testqa)
- [Step 3b: done.sh](#step-3b-donesh)
- [Step 4: Ship (PR 생성)](#step-4-ship-pr-생성--루프-밖-1회만-실행)
- [루프 제어](#루프-제어)
- [출력 형식](#출력-형식)

---

## 전제 조건

- 이미 plan/design doc이 있거나, 요구사항이 명확한 상태 (없어도 진행 가능 — `tdd`/`full` 모드처럼 인터뷰하지 않는다)
- feature branch에서 작업 중

## 실행 흐름

```
Step 0: 사전 점검 + done.sh 작성 → 기준선(새 동작 AC 는 FAIL) → 동결
Loop (완료 판정 루프 — 실패 집합이 비고 done.sh exit 0 까지, 진척 없이 3회·전체 10회·재시도 무의미에서 멈춤):
  Step 1: Build (구현)
    ↓ FAIL → 자동 수정 1번 → 이번 반복은 F={BUILD} 로 끝내고 멈춤 조건 검사 (Step 2·3·3b 건너뜀)
  Step 2: Co-Review — 첫 반복과, done.sh 가 처음 통과한 직후에만(첫 리뷰 뒤 바뀐 코드가 없으면 생략) (Claude 리뷰 · Codex 는 리뷰 요청 시만)
    ↓ FAIL (Critical 잔존) → 자동 수정 → Step 2 재시도
    ↓ CONFLICT → 사용자에게 질문 (자동 수정 안 함, 디버깅 문서의 "리뷰 의견 충돌" 분류)
  Step 3: Test/QA
    ↓ 웹 프로젝트 → e2e 스킬 (브라우저 QA) · 비웹 프로젝트 → verify 또는 test-and-fix 스킬
    ↓ FAIL → F 에 TEST 를 넣고 Step 3b 로
  Step 3b: done.sh 실행 → F 확정
    ↓ F 가 비고 exit 0 → (마지막 Co-Review 를 아직 안 했으면 Step 2 → 수정이 있었으면 다음 반복) → 루프 종료
    ↓ 아니면 멈춤 조건 검사 → 다음 반복 (Step 1)

Step 4: Ship (PR 생성) — 루프 밖, 1회만 실행. 공통 하드 게이트(머지 직전 테스트 통과)는 병합 시점에 적용
```

이 루프는 [SKILL.md의 공통 하부 컴포넌트](../skills/cycle/SKILL.md#공통-하부-컴포넌트) — 완료 판정 루프 + 에러 분류 — 를 그대로 사용한다. 멈춤 조건은 [done-loop.md](done-loop.md#루프와-멈춤-조건), 분류 기준은 [debugging.md](debugging.md) 참조.

## Step 0: 사전 점검

```bash
git status -sb && git branch --show-current
```

- main/master에서 작업 중이면 → "feature branch에서 작업하세요" 경고 후 중단
- 커밋 안 된 변경이 있으면 → 먼저 stash 또는 커밋 제안

spec.md, design doc, CLAUDE.md 등 프로젝트 맥락이 있으면 읽는다 (없어도 진행).

**done.sh 작성 (구현 전)**: `$ARGUMENTS` 에서 완료 조건을 AC-01.. 로 뽑아 하나에 `check` 한 줄씩 `done.sh` 로 쓴다. 위치는 커밋되지 않는 `$DONE_DIR/done.sh` 다 — `DONE_DIR` 계산(절대 git dir, 브랜치 이름 퍼센트 인코딩, detached HEAD 면 중단)은 [done-loop.md 계약](done-loop.md#donesh-계약)의 스니펫을 그대로 쓴다. 한 번 돌려 `baseline.txt` 에 남기고(새 동작 AC 는 FAIL 이어야 한다) `cp done.sh done.sh.frozen` 으로 동결한다. quick 은 승인 단계가 없으므로 **구현 시작 시점이 동결 시점**이고, 진행 메모에 AC 목록을 한 번 보여 준다. 명령으로 확인할 수 없는 AC 는 MANUAL 로 두지 않고 사용자에게 묻는다.

quick 은 가볍게 유지한다. `STATE.md` 와 Done Loop 표는 **첫 실패 반복이 나온 뒤에야** `$DONE_DIR/STATE.md` 로 만든다 — 첫 반복에 통과하면 남길 기록이 `baseline.txt` 와 마지막 done.sh 출력뿐이다.

## Step 1: Build (구현)

`$ARGUMENTS` 기반으로 구현한다. `tdd`/`full` 모드와 달리 RED→GREEN→REFACTOR를 강제하지 않는다 — 다만 테스트 작성이 자연스러운 경우 함께 작성한다.

**구현 시:**
- 기존 코드 패턴을 먼저 파악 (`rg`, `ast-grep` 활용)
- 테스트 가능하면 테스트도 함께 작성
- 구현 완료 후 빌드 확인

**빌드 실패 시:**
1. 에러 분석 ([debugging.md](debugging.md)의 에러 분류로 재시도 유효성 판단)
2. 자동 수정 후 재빌드 **한 번이 한 반복**이다. 재빌드도 실패하면 이번 반복은 F={BUILD} 로 끝낸다 — Step 2·3·3b 를 건너뛰고 Done Loop 표에 `BUILD` 를 적은 뒤 [멈춤 조건](done-loop.md#루프와-멈춤-조건)을 검사한다. 그래서 빌드가 계속 깨져도 진척 없이 3회·전체 10회에서 반드시 멈춘다

**PASS 조건**: 빌드 성공 (에러 0)

> **[진행]** 묻지 않고 첫 반복은 Step 2(Co-Review)로, 그 뒤 반복은 Step 3 으로 넘어간다 — quick 은 무인 모드다

## Step 2: Co-Review (Claude + Codex 교차 리뷰)

**실행 시점: 첫 반복, 그리고 `done.sh` 가 처음 통과한 직후 한 번.** 반복마다 돌리지 않는다. 첫 반복 리뷰 뒤 코드가 바뀌지 않았으면(첫 반복에 바로 통과) 통과 직후 리뷰는 생략한다.

**이 단계가 핵심 — 확증 편향 방지를 위해 Codex에 프로젝트 컨텍스트를 주입한다. 이 리뷰는 모든 모드 공통인 "PR 생성 직전 적대 리뷰" 하드 게이트를 겸한다.**

### 2-A: Claude 리뷰 (직접)
- `git diff` 결과를 직접 읽는다
- 변경된 파일의 호출부/의존부를 `rg`로 탐색하여 함께 읽는다
- spec.md, CLAUDE.md가 있으면 읽고 spec 준수 여부를 검증한다
- 관점: 버그, 보안, 성능, spec 준수, 아키텍처 일관성, 호출부 호환성

### 2-B: Codex 리뷰 (병렬, 단일 bash 블록)

**리뷰를 요청했을 때(`--review` 또는 요청 문장에 "리뷰")만 실행한다** — 요청이 없으면 2-A 만 하고 결과에 "Codex 리뷰 생략(요청 없음)" 을 적는다.

컨텍스트 수집과 Codex 호출을 **하나의 bash 블록**에서 실행한다 (변수 스코프 보장). `codex-advisor` 에이전트 또는 `/codex:review` 커맨드로 위임해도 된다:

```bash
# 컨텍스트 수집 + Codex 호출을 단일 블록에서 실행
SPEC=$(head -c 4000 spec.md 2>/dev/null || head -c 4000 docs/specs/*.md 2>/dev/null || echo "No spec")
ARCH=$(head -c 2000 CLAUDE.md 2>/dev/null || echo "No CLAUDE.md")
CHANGED_FILES=$(git diff --name-only 2>/dev/null)
RELATED=""
for f in $CHANGED_FILES; do
  fname=$(basename "$f" | sed 's/\.[^.]*$//')
  hits=$(rg -l --max-count=3 "$fname" --type-add 'src:*.{ts,tsx,js,jsx,py,java,kt,go}' -t src 2>/dev/null | grep -v "$f" | head -3)
  [ -n "$hits" ] && RELATED="$RELATED $hits"
done
RELATED=$(echo "$RELATED" | tr ' ' '\n' | sort -u | head -10 | tr '\n' ' ')
DIFF_CONTENT=$(git diff | head -c 30000)

# 프롬프트를 임시 파일에 작성 (shell injection 방지)
PROMPT_FILE=$(mktemp ${TMPDIR:-/tmp}/sos-quick-prompt-XXXXXXXX.txt)
cat > "$PROMPT_FILE" << REVIEWEOF
You are reviewing code with FULL PROJECT CONTEXT.

PROJECT SPEC:
$SPEC

ARCHITECTURE (CLAUDE.md):
$ARCH

RELATED FILES (callers/dependents): $RELATED

CODE CHANGES:
$DIFF_CONTENT

Review for:
1. BUGS: Logic errors, null risks, race conditions
2. SECURITY: Injection, auth bypass, data exposure
3. SPEC COMPLIANCE: Do changes match the spec?
4. ARCHITECTURE: Do changes follow CLAUDE.md patterns?
5. CALLER COMPATIBILITY: Will related files break?
6. MISSING TESTS: What tests are needed?

For each: severity (Critical/Warning/Suggestion), file:line, explanation.
REVIEWEOF

codex exec -s read-only -o ${TMPDIR:-/tmp}/sos-quick-codex.txt "$(cat "$PROMPT_FILE")" 2>/dev/null
rm -f "$PROMPT_FILE"
echo "Codex review 완료: $(wc -l < ${TMPDIR:-/tmp}/sos-quick-codex.txt 2>/dev/null || echo 0) lines"
```

Codex 실패/타임아웃 시 → Claude 단독 리뷰로 진행 (Codex는 품질 보너스, 게이트 아님)

### 2-C: 합성 + 자동 수정

| 신뢰도 | 조건 | 처리 |
|--------|------|------|
| **HIGH** | Claude + Codex 동의 | **자동 수정** |
| **MEDIUM** | 한쪽만 발견 | **자동 수정** (보수적 접근) |
| **CONFLICT** | 의견 상충 | **루프 중단 → 사용자에게 양쪽 근거 제시 후 질문** |

**CONFLICT 처리** (quick 무인 진행의 예외 — 결과가 갈리는 결정): 자동화 루프에서 의견 충돌을 자동 해결하면 위험. 번호 붙인 평문 질문으로 양쪽 근거를 제시하고 사용자 판단을 받는다 (디버깅 문서의 "리뷰 의견 충돌" 분류 — 재시도 무의미).

**Codex 실패 처리**:
- Codex 미설치 (`which codex` 실패) → Claude 단독 리뷰로 진행
- 인증 실패 (stderr에 "auth"/"login") → "codex login 실행 필요" 안내 후 Claude 단독
- 타임아웃 (180초) → Claude 단독
- 빈 결과 → Claude 단독

Critical 이슈 → 자동 수정 후 재빌드.
수정 후에도 Critical 잔존 (2회 시도 후) → 사용자에게 보고 후 중단.

```bash
rm -f ${TMPDIR:-/tmp}/sos-quick-codex.txt
```

**PASS 조건**: Critical 0건

> **[진행]** 묻지 않고 Step 3(Test/QA)로 넘어간다

## Step 3: Test/QA

프로젝트 타입에 따라 검증 방법을 선택한다:

**웹 프로젝트** (UI가 있는 경우):
- `e2e` 스킬 실행 → 브라우저 QA + 버그 수정
- PASS 조건: 핵심 플로우 통과

**비웹 프로젝트** (CLI, 라이브러리, API):
- `verify` 스킬 (build + type check + lint + test) 또는 `test-and-fix` 스킬 (테스트 실행 + 실패 수정)
- PASS 조건: 모든 테스트 통과

**FAIL**: 수정 후에도 실패 → 실패 집합에 `TEST` 로 넣고 Step 3b 로

## Step 3b: done.sh

```bash
# DONE_DIR: same snippet as done-loop.md (absolute git dir + percent-encoded branch)
[ -f "$DONE_DIR/done.sh" ] && [ -f "$DONE_DIR/done.sh.frozen" ] || echo "DONESH: missing done.sh or frozen copy"
cmp -s "$DONE_DIR/done.sh.frozen" "$DONE_DIR/done.sh" || diff -u "$DONE_DIR/done.sh.frozen" "$DONE_DIR/done.sh"
bash "$DONE_DIR/done.sh"; echo "exit=$?"
```

F 를 확정한다. 종료 코드가 0·1 이 아니거나 `DONE` 줄이 없거나 파일이 없으면 F 에 `DONESH` 를 넣고 곧바로 BLOCKED 다(fail-closed). F 가 비고 exit 0 이면, 마지막 Co-Review 를 하고 수정이 없으면 루프를 끝낸다. 수정이 있었으면 다음 반복에서 Step 3·3b 를 다시 돈다. 그 밖에는 Done Loop 표에 한 줄 남기고 멈춤 조건을 검사한 뒤 Step 1 로 돌아간다. 동결본과 다르면 [done-loop.md 「약하게 만들지 않는다」](done-loop.md#donesh-를-약하게-만들지-않는다)를 따른다.

> **[확인 게이트 — 유지]** → 평문 질문: "done.sh exit 0 (DONE N/N). Step 4(Ship/PR 생성)를 진행할까요? (커밋·푸시·PR이 생성됩니다)" — 밖으로 나가는 행동이라 묻는다. 질문에 마지막 done.sh 출력 전문을 붙인다

## Step 4: Ship (PR 생성) — 루프 밖, 1회만 실행

**Step 1~3b 루프가 ALL PASS(`done.sh` exit 0)한 후에만 실행한다.** Ship은 커밋, 푸시, PR 생성을 수행하므로 반복하면 중복 커밋/PR이 생긴다. [verify-compound.md의 브랜치 마무리](verify-compound.md#브랜치-마무리) 절차를 그대로 따른다 (Option 1-4 동일) — quick 모드는 문서/Compound 단계가 없으므로 완료 보고 후 바로 브랜치 마무리로 넘어간다.

**PASS 조건**: PR URL 생성
**FAIL**: 테스트 실패 → 묻지 않고 Step 1~3b 루프로 돌아간다. 멈춤 조건에 걸릴 때만 멈추고 보고한다

## 루프 제어

```
MAX_ITER=10
loop_iter=0; stall=0; history=[]; reviewed_once=False   # baseline (iter 0) is NOT in history
reviewed_after_pass=False; changed_since_review=True    # no review yet; co_review() sets False, any later fix sets True

loop:
  loop_iter++
  if not build_ok_after_one_fix():        # Step 1: one fail→fix→rebuild = one iteration
    F = {BUILD}                           # skip Steps 2, 3, 3b
  else:
    if not reviewed_once: co_review(); reviewed_once=True; changed_since_review=False   # Step 2 on the first built pass only
    F = failed of {TEST} ∪ FAIL AC-xx ∪ ({DONESH} if done.sh broken)   # Steps 3, 3b
    if DONESH in F: BLOCKED (non-retryable)
    if F empty and done.sh exit 0:
      if reviewed_after_pass or not changed_since_review or not co_review_made_changes(): break → Step 4 (Ship)
      reviewed_after_pass=True; continue  # review changed code: rebuild, re-run Steps 3, 3b
  stall = 0 if loop_iter == 1 or F ⊊ history[-1] else stall + 1
  history.append(F); record Done Loop row (create STATE.md on the first failing iteration)
  if (stall >= 2 and some item in history[-1] ∩ history[-2] ∩ history[-3])
     or loop_iter >= MAX_ITER or failure is non-retryable:
    → BLOCKED: report Done Loop table + last done.sh output (debugging.md)
```

Step 2 Co-Review 의 Critical·CONFLICT 는 `done.sh` 로 판정할 수 없는 판단이라 이 집합에 넣지 않고 기존 규칙(Critical 2회 수정 실패 시 보고, CONFLICT 는 즉시 질문)을 따른다. 판정 규칙의 정본: [done-loop.md](done-loop.md#루프와-멈춤-조건)

## 출력 형식

### 진행 중:
```
=== Dev Cycle (quick) Iteration 2/10 (stall 0) ===
[PASS] Step 1: Build — 수정 반영 (iter 1 실패 집합: AC-02)
[SKIP] Step 2: Co-Review — 첫 반복에 실행함, done.sh 통과 직후 다시 실행
[SKIP] Step 3: QA — CLI 프로젝트
[PASS] Step 3b: done.sh — exit 0, DONE 3/3
[PASS] Step 2: Co-Review (통과 직후) — Critical 0, Warning 1 (Suggestion, 수정 없음)
[PASS] Step 4: Ship — PR #42 생성
=== Dev Cycle (quick) Complete (2 iterations) ===
```

### 실패 시:
```
=== Dev Cycle (quick) Iteration 2/10 ===
[PASS] Step 1: Build
[FAIL] Step 2: Co-Review — Critical 1건 잔존 (2회 수정 실패)
  - Codex 발견: SQL injection 위험 (src/db.ts:42)
  - Claude 동의: HIGH confidence
  - 자동 수정 2회 시도했으나 패턴이 복잡하여 해결 불가
  → 수동 개입 필요: src/db.ts:42 parameterized query로 변경
=== Dev Cycle (quick) Paused ===
```
