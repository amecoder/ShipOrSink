# Implement (TDD) 상세 — Phase 2: RED → GREEN → REFACTOR

> [cycle](../skills/cycle/SKILL.md)에서 링크됨. `tdd`/`full` 모드에서 실행. `quick` 모드의 구현 루프는 [quick-mode.md](quick-mode.md) 참조.

## 목차
- [Pre-Flight 플랜 검토](#pre-flight-플랜-검토)
- [실행 모드 선택](#실행-모드-선택)
- [Phase 2 공통 품질 계약](#phase-2-공통-품질-계약)
- [Inline 모드](#inline-모드-기본)
- [SDD 모드 (서브에이전트 기반)](#sdd-모드-서브에이전트-기반)

---

## Pre-Flight 플랜 검토

실행 모드 선택 전에 DESIGN.md 태스크 분해 + PLAN/SPEC 전체를 **1회 스캔**한다:

- 태스크 간 모순, SPEC 제약·Invariant와 충돌하는 태스크
- 플랜이 명시했지만 리뷰 기준으로는 결함인 것 (아무것도 검증하지 않는 테스트, 로직 블록 그대로 복제 등)

발견 사항은 **한 번에 배치 질문**으로 제시한다 — 각 발견 옆에 근거 문서를 인용하고 어느 쪽이 우선인지 묻는다. 태스크 중간 인터럽트를 만들지 않는다. 스캔이 깨끗하면 무언급 진행. 구현 중에만 드러나는 충돌은 리뷰 루프가 잡는다.

## 실행 모드 선택

| 모드 | 설명 | 적합한 상황 |
|------|------|------------|
| **Inline** (기본) | 메인 컨텍스트에서 직접 실행 | 태스크 1-3개, 긴밀한 의존성 |
| **SDD** (`--sdd`) | 태스크별 fresh 서브에이전트 + 2단계 자동 리뷰 | 태스크 3개 이상, 독립적 단위 |

**SDD 모드 자동 제안 조건:**
- DESIGN.md의 태스크 분해에서 독립 태스크 3개 이상
- 태스크 간 파일 충돌 없음
- 각 태스크가 자체 테스트로 검증 가능

`--sdd`는 전체 사이클(문서+구현) 실행을 암시한다.

## Phase 2 공통 품질 계약

실행 모드에 관계없이, 각 태스크(또는 RED→GREEN→REFACTOR 사이클) 완료 시 다음이 모두 충족되어야 한다:

| 항목 | 설명 | Inline | SDD |
|------|------|--------|-----|
| `red_evidence` | RED 테스트 실패 출력 | 직접 실행 | 구현 에이전트가 보고 |
| `green_evidence` | GREEN 테스트 통과 출력 | 직접 실행 | 구현 에이전트가 보고 |
| `refactor_evidence` | REFACTOR 후 테스트 재통과 | 직접 실행 | 구현 에이전트가 보고 |
| `changed_files` | 변경된 파일 목록 (`git diff --name-only`) | STATE.md에 기록 | 리뷰 에이전트에 전달 |
| `regression_cmd` | 이 태스크 테스트 재실행 명령 | STATE.md에 기록 | STATE.md에 기록 |
| `spec_review` | AC 매핑 확인 | Phase 3 Step 8 | Spec 리뷰 에이전트 |
| `code_review` | 코드 품질 확인 | Phase 3 완료 후 (선택) | 코드 리뷰 에이전트 |

---

## Inline 모드 (기본)

### Step 4: RED — 테스트 작성

DESIGN.md의 테스트 계획표를 기반으로 테스트 코드를 작성한다.

1. DESIGN.md를 읽는다
2. 테스트 파일을 생성한다 (프로젝트 컨벤션에 맞게)
3. 모든 테스트를 실행하여 **FAIL 확인**한다

```bash
# node: pnpm test / npm test / bun test
# python: pytest --tb=short
# jvm: ./gradlew test
# go: go test ./...
# rust: cargo test
```

**새로 추가한 테스트는 기대한 이유로 실패해야 하고, 기존 테스트는 통과해야 한다.** 새 테스트가 즉시 통과하면 이미 구현된 동작을 테스트한 것이므로, 아직 구현되지 않은 동작을 검증하도록 재작성한다.

4. **RED 스냅샷 커밋:**

```bash
git add 테스트파일들
git commit -m "테스트: [기능명] RED — 실패하는 테스트 작성"
```

5. **done.sh 기준선 + 동결** (Phase 1 에서 쓴 `$FEATURE_DIR/done.sh` 가 있을 때): RED 커밋 직후 `bash "$FEATURE_DIR/done.sh"` 를 돌려 새 동작 AC 가 **테스트 실패 때문에** FAIL 인지 로그로 확인한다(no tests collected·파일 없음이면 명령을 고친다). 이 실행이 기준선이다. `cp done.sh done.sh.frozen` 하고 기준선 보고에 `diff -u done.sh.approved done.sh` 를 붙인다. RED 커밋 해시는 STATE.md `done.tests_frozen_at` 에 남긴다 — [done-loop.md](done-loop.md#작성-시점기준선동결)

### TDD Iron Law — 합리화 방지

```
이 시점 이후, Phase 2-3 전체에서:

✅ 허용:
- 테스트 헬퍼/유틸리티 함수 추가
- setup/teardown/beforeEach 수정
- 테스트 fixture/mock 데이터 수정
- 새로운 테스트 케이스 추가

❌ 금지:
- 기존 테스트의 expect/assert/toBe 값 변경
- 기존 테스트의 검증 조건 완화
- 기존 테스트 삭제 또는 skip 처리
- DESIGN.md의 "기대 결과" 칼럼 수정
- 테스트 전에 쓴 구현 코드를 "참고용"으로 유지

위반 시: 구현이 잘못된 것이지 테스트가 잘못된 것이 아니다.

⚠️ TEST_INVALID 프로토콜 (유일한 예외):
테스트 자체가 잘못 작성됐거나 SPEC/DESIGN이 틀린 경우:
1. 테스트가 아닌 SPEC.md 또는 DESIGN.md를 먼저 수정한다
2. 변경 이유를 STATE.md Progress Log에 기록한다
3. 수정된 스펙에 맞춰 테스트를 다시 작성한다 (기존 테스트 수정이 아닌 재작성)
4. RED를 재실행하여 실패를 확인한다
→ 이 프로토콜 없이 테스트를 수정하는 것은 여전히 금지
```

**합리화 감지 — 이 생각이 들면 STOP:**

| 합리화 | 현실 |
|--------|------|
| "이건 너무 단순해서 테스트 불필요" | 단순한 코드도 깨진다. 테스트 30초. |
| "나중에 테스트 추가할게" | 즉시 통과하는 테스트는 아무것도 증명 안 함 |
| "참고용으로 남겨두고 테스트 먼저 쓸게" | 참고하는 순간 TDD가 아님. 삭제 = 삭제 |
| "탐색이 필요해서 먼저 코드를 써봤어" | 탐색 끝나면 버려라. TDD로 새로 시작 |
| "테스트 어려움 = 나중에 해야" | 테스트 어려움 = 설계가 복잡함. 인터페이스 단순화 |
| "시간 아까워서 삭제 못 해" | 매몰 비용 오류. 검증 안 된 코드가 진짜 낭비 |
| "실용적으로 판단하면 TDD 스킵" | TDD가 실용적. 디버깅보다 빠름 |
| "이미 수동으로 테스트했어" | 수동 테스트는 일회성. 재현·회귀 불가 |

**RED FLAGS — 이 상황이면 코드를 삭제하고 TDD로 재시작:**
- 테스트 전에 코드를 먼저 씀
- 테스트가 즉시 통과함
- 왜 실패했는지 설명 못 함
- "이번만" 스킵하려고 합리화 중

STATE.md 갱신: `step: red → PASS`

> **[확인 게이트 — `full` 모드만, `tdd` 는 묻지 않고 진행]** 평문 질문: "Step 4(RED) 완료 — 실패하는 테스트 작성됨. Step 5(GREEN/최소 구현)를 시작할까요?"

### Step 5: GREEN — 최소 구현

테스트를 통과하는 **최소한의 코드**를 작성한다.

**실패 시**: [체계적 디버깅 프로세스](debugging.md)를 따른다 — 임의 수정 금지.
`retry_count`를 갱신하며, 같은 테스트가 진척 없이 3회 실패하면 BLOCKED ([회로차단기 정책](debugging.md#진척-없는-3회-회로차단기--에러-분류) 참조).

**테스트 통과 직후 STATE.md의 `regression` 블록을 기록한다:**

```yaml
regression:
  cmd: "<실제 사용한 테스트 실행 명령어>"
  cwd: "."
  env: {}
```

STATE.md 갱신: `step: green`, `retry_count` 업데이트, `regression.cmd` 기록

> **[확인 게이트 — `full` 모드만, `tdd` 는 묻지 않고 진행]** 평문 질문: "Step 5(GREEN) 완료 — 모든 테스트 통과. Step 6(REFACTOR)를 진행할까요?"

### Step 6: REFACTOR

테스트가 **여전히 통과하는** 범위에서 코드를 개선한다.

- 중복 제거, 네이밍 개선, 파일 분리 (200-400줄 기준)
- 프로젝트 코딩 스타일 적용

리팩터 후 반드시 테스트 재실행.

STATE.md 갱신: `step: refactor → PASS`

> **[확인 게이트 — Phase 3 시작 · `full` 모드만]** 평문 질문: "Phase 2(TDD 구현) 완료. Phase 3(검증)를 시작할까요?"

**`full` 모드 추가 게이트**: RED/GREEN/REFACTOR 각 단계 게이트는 이미 위에 명시된 대로 개별 실행한다 (스킵·묶음 승인 금지). SDD 모드에서는 태스크별 완료 시에도 동일하게 개별 게이트를 유지한다.

---

## SDD 모드 (서브에이전트 기반)

**`--sdd` 플래그 시 Phase 2를 이 모드로 실행한다.**

서브에이전트에 태스크를 위임하되, 메인 세션은 조율(coordination)에 집중한다.
각 서브에이전트는 fresh context로 실행되어 컨텍스트 오염을 방지한다.

### SDD 원칙

- **Fresh context per task**: 서브에이전트는 세션 히스토리를 상속받지 않는다
- **파일 핸드오프**: 대용량 산출물은 파일로 전달하고 프롬프트에는 **경로만** 넣는다 — 프롬프트에 붙여넣은 텍스트와 서브에이전트 출력은 세션 끝까지 메인 컨텍스트에 상주하며 매 턴 재독된다
  - 태스크 브리프: DESIGN.md에서 해당 태스크 전문+AC 매핑을 `$FEATURE_DIR/tasks/task-N-brief.md`로 추출
  - 구현 리포트: 서브에이전트가 `$FEATURE_DIR/tasks/task-N-report.md`에 상세 기록(TDD 증거 포함), 반환은 상태·커밋·테스트 1줄 요약만 (15줄 이내)
  - 리뷰 diff: `git diff $TASK_START_SHA..HEAD > $FEATURE_DIR/tasks/task-N-diff.txt`로 저장해 리뷰 에이전트에 경로 전달
- **이전 태스크 히스토리 금지**: dispatch에는 ①태스크 위치 한 줄 ②브리프 경로 ③이전 태스크의 인터페이스·결정 ④모호성 해석 ⑤리포트 경로만 — 누적 요약 붙여넣기 금지
- **연속 실행**: 태스크 간 사용자 확인 없이 연속 진행 — 멈추는 경우: BLOCKED, 해결 불가 모호성, 전체 완료
- **순차 실행**: 구현 서브에이전트를 병렬로 디스패치하지 않는다 (파일 충돌 위험)

### SDD 프로세스

**첫 디스패치 전 — done.sh 기준선·동결** (Phase 1 에서 쓴 `$FEATURE_DIR/done.sh` 가 있을 때): `bash "$FEATURE_DIR/done.sh"` 를 돌려 기준선으로 남기고 "테스트가 아직 없어서 FAIL"이라고 표시한다. 이어서 `cp done.sh done.sh.frozen` 하고 기준선 보고에 `diff -u done.sh.approved done.sh` 를 붙인다. 테스트 diff 기준은 파일마다 그 파일을 추가한 커밋(`git log --diff-filter=A --format=%H -1 -- <테스트 파일>`)이다 — [done-loop.md](done-loop.md#작성-시점기준선동결). 이 단계를 건너뛰면 Phase 3 Step 8 이 `done.sh.frozen` 없음으로 BLOCKED 된다.

```
DESIGN.md 태스크 분해 읽기
  → 전체 태스크 목록 추출 + 의존성 확인
  → 태스크별 반복:

  1. 구현 서브에이전트 디스패치 (파일 핸드오프)
     - 태스크 브리프 파일 경로 (task-N-brief.md — 태스크 전문+AC 매핑)
     - 관련 파일 경로 + 이전 태스크의 인터페이스·결정
     - TDD 규칙 (RED→GREEN→REFACTOR 강제) + 리포트 파일 경로

  1.5. 태스크 시작 전 사전 검사 + 체크포인트
     ```bash
     # dirty tree가 있으면 태스크를 시작하지 않는다
     if [ -n "$(git status --porcelain)" ]; then
       echo "WARN: dirty tree — stash 또는 커밋 후 진행"
       # → 평문 질문: "dirty tree입니다. stash / 커밋 / 중단?"
     fi
     TASK_START_SHA=$(git rev-parse HEAD)
     ```

  2. 구현 서브에이전트 상태 처리

     **DONE** → Spec 리뷰로 진행

     **DONE_WITH_CONCERNS** → severity 평가:
       - low (관찰 사항, "이 파일 커지고 있음") + AC 통과 → 메모 후 진행
       - medium/high (정확성·범위 우려) → 구현 에이전트에 수정 요청 후 재확인 (최대 2회, 초과 시 BLOCKED)

     **NEEDS_CONTEXT** → 추가 정보 제공 후 재디스패치 (최대 2회, 초과 시 태스크 분해 또는 BLOCKED)

     **BLOCKED** → 원인 분석:
       a) 컨텍스트 부족 → 보충 후 재시도
       b) 태스크 과대 → 분해
       c) 플랜 오류 → 사용자 에스컬레이션

     **타임아웃 / 도구 실패** → 부분 실패 복구:
       ```bash
       TASK_CHANGED_FILES=$(git diff --name-only $TASK_START_SHA)
       ```
       - 변경 없음 → 재디스패치
       - 변경 있음 → 평문 질문: "서브에이전트가 부분 완료 후 실패했습니다. 변경 유지 / 롤백 / 분리 브랜치?"
       - 롤백 선택 시: 태스크가 변경한 파일만 되돌린다
         ```bash
         git diff --name-only $TASK_START_SHA | xargs git checkout $TASK_START_SHA --
         ```

  3. Spec 준수 리뷰 (서브에이전트)
     - SPEC.md의 해당 AC 목록을 건네주고
     - 구현이 AC를 충족하는지, 과도하게 구현하지 않았는지 확인
     - ❌ → 구현 에이전트가 수정 → 재리뷰
     - ✅ → 코드 품질 리뷰로 진행

  4. 코드 품질 리뷰 (서브에이전트)
     - diff 파일 경로 제공 (task-N-diff.txt) + 구현 리포트는 검증 안 된 주장으로 취급하게 명시
     - 코드 품질, 테스트 품질, 프로젝트 컨벤션 준수 확인
     - ❌ → 구현 에이전트가 수정 → 재리뷰
     - ✅ → 태스크 완료

  5. STATE.md 갱신: 태스크 완료 기록

전체 태스크 완료 후:
  → 최종 통합 리뷰 (전체 구현에 대한 코드 리뷰 서브에이전트)
  → Phase 3 진행
```

### 서브에이전트 모델 선택

비용 최적화를 위해 태스크 복잡도에 따라 모델을 선택한다:

| 태스크 유형 | 모델 | 기준 |
|------------|------|------|
| 단순 구현 (1-2 파일, 명확한 스펙) | 가벼운 모델 (sonnet/haiku) | 기계적 코딩 |
| 통합·판단 (다중 파일, 패턴 매칭) | 기본 모델 (sonnet) | 컨텍스트 연결 필요 |
| 설계·리뷰 (아키텍처 이해 필요) | 강한 모델 (opus) | 넓은 맥락 필요 |

### SDD Red Flags

- Spec 리뷰 전에 코드 리뷰 시작 (순서 위반)
- 구현 에이전트를 병렬로 디스패치 (충돌)
- 서브에이전트에게 STATE.md나 PLAN.md 전체를 읽게 시킴 (태스크 브리프 파일만 전달)
- 서브에이전트의 질문을 무시하고 강행
- "close enough"로 Spec 리뷰 통과 처리
- 리뷰에서 지적된 이슈를 수정 없이 다음 태스크로 이동
- 리뷰어 프롬프트에 사전 판정 지시 포함 ("이건 flag하지 마라" — [리뷰 결과 수신 규율](brainstorm-design.md#리뷰-결과-수신-규율-게이트-ⓐⓑsdd-리뷰quick-모드-co-review-공통) 참조)
- 구현 에이전트 탈선 3신호 방치: ①과도한 루프·재시도 ②요청 안 한 기능 추가 ③테스트 비활성화·삭제·조작 — 발견 즉시 중단하고 수정 디스패치 (Kent Beck)

다음 단계: [verify-compound.md](verify-compound.md)
