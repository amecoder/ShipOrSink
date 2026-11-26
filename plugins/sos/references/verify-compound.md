# Verify & Compound 상세 — Phase 3(VERIFY) + Phase 4(COMPOUND)

> [cycle](../skills/cycle/SKILL.md)에서 링크됨. Phase 3는 `tdd`/`full` 모드 전용 (`quick` 모드의 경량 검증은 [quick-mode.md](quick-mode.md) 참조). 완료 보고·브랜치 마무리·공통 하드 게이트(PR 생성 직전/머지 직전)는 모든 모드 공통이다.

## 목차
- [Phase 3: VERIFY (검증)](#phase-3-verify-검증)
- [완료 보고](#완료-보고)
- [브랜치 마무리](#브랜치-마무리)
- [Phase 4: COMPOUND (학습 환류)](#phase-4-compound-학습-환류)

---

## Phase 3: VERIFY (검증)

**증거 게이트 — 모든 검증 항목에 적용:**

```
각 검증 항목에 대해:
  1. IDENTIFY: 이 주장을 증명하는 명령은?
  2. RUN: 해당 명령을 실행한다 (이전 결과 재사용 금지)
  3. READ: 전체 출력을 읽고, exit code를 확인하고, 실패 수를 센다
  4. VERIFY: 출력이 주장을 뒷받침하는가?
     - NO → 실제 상태를 증거와 함께 보고
     - YES → 증거와 함께 주장
  5. ONLY THEN: 결과를 보고
```

**합리화 감지 — 이 표현이 나오면 STOP:**
- "should work now" / "아마 될 것이다"
- "looks correct" / "맞아 보인다"
- "confident" / "확신한다" (증거 없이)
- "Great!", "Perfect!", "Done!" (검증 전)
- "just this once" / "이번만"

**실패 시**: [체계적 디버깅 프로세스](debugging.md) 참조. Step 7·8 실패는 [완료 판정 루프](done-loop.md#루프와-멈춤-조건)의 실패 집합으로 세고, 멈춤 조건에 걸릴 때만 BLOCKED.

### Step 7a: Build

```bash
# node: pnpm build (또는 npm run build)
# python: python -m py_compile <changed_files>
# jvm: ./gradlew build -x test (또는 mvn compile)
# go: go build ./...
# rust: cargo build
```

| 증거 | 필요 | 불충분 |
|------|------|--------|
| 빌드 성공 | 빌드 명령: exit 0 | 린터 통과, "코드가 맞아 보인다" |

STATE.md 갱신: `verify.build: PASS|FAIL`

### Step 7b: Type Check

```bash
# TypeScript: npx tsc --noEmit
# Python: pyright (또는 mypy)
# JVM/Rust: 빌드 단계에 포함 — SKIP
```

STATE.md 갱신: `verify.typecheck: PASS|FAIL|SKIP`

### Step 7c: Lint

```bash
# JS/TS: npx eslint . (eslintrc 존재 시)
# Python: ruff check . (또는 flake8)
# Kotlin: ./gradlew ktlintCheck
# Rust: cargo clippy
# Go: golangci-lint run
```

STATE.md 갱신: `verify.lint: PASS|FAIL`

### Step 7d: Unit Test + Coverage

```bash
# node: pnpm test -- --coverage
# python: pytest --cov --tb=short
# jvm: ./gradlew test jacocoTestReport
# go: go test -cover ./...
# rust: cargo tarpaulin
```

| 증거 | 필요 | 불충분 |
|------|------|--------|
| 테스트 통과 | 테스트 명령 출력: 0 failures | 이전 실행, "통과할 것이다" |
| 커버리지 80%+ | 커버리지 리포트: XX% | 테스트 수가 많아서 |

STATE.md 갱신: `verify.test: PASS|FAIL`, `verify.coverage: XX%`

**Step 7 전체 FAIL 시**: 실패한 단계의 증거와 함께 보고. [체계적 디버깅 프로세스](debugging.md) 참조.

**`full` 모드**: 완료 판정 루프의 첫 회에는 Step 7a/7b/7c/7d를 개별적으로 실행하고 **각 단계마다** 번호 붙인 평문 질문으로 다음 단계 진행 여부를 확인한다 ("Step 7a(Build) PASS. Step 7b(Typecheck)를 진행할까요?" 형식). 두 번째 반복부터는 반복당 한 번만 묻는다([done-loop.md](done-loop.md#루프와-멈춤-조건)). `tdd` 모드(기본)는 Step 7 전체를 한 번에 실행하고 결과를 묶어서 보고한 뒤 다음 게이트로 넘어간다.

### Step 8: Spec Verification — `done.sh`

Phase 2 RED 커밋 직후 동결한 `$FEATURE_DIR/done.sh` 를 실행한다. 판정은 **종료 코드**다 — 모델이 AC 체크박스에 표시한 것은 근거가 아니다.

```
done.sh·done.sh.frozen 이 있는가? cmp -s 로 같은가? → 없으면 DONESH, 다르면 done-loop.md 「약하게 만들지 않는다」 절차
bash "$FEATURE_DIR/done.sh"; echo "exit=$?"
exit 0 이고 Step 7 실패 없음 → PASS (출력 전문을 STATE.md·완료 보고에 붙인다)
exit 1 → FAIL 인 AC-xx 가 GAP → Step 4 회귀, 완료 판정 루프 계속
exit 0·1 이 아님, 또는 DONE 줄 없음 → DONESH → 곧바로 BLOCKED (fail-closed)
```

Step 7 과 Step 8 은 하나의 완료 판정 루프로 반복한다. `tdd` 는 실패 집합이 비고 `done.sh` 가 exit 0 일 때까지 묻지 않고 계속하고(`full` 은 반복마다 실패 집합과 다음 가설을 보여 주고 한 번 확인 — 7a~7d 개별 질문은 첫 회만), 진척 없이 3회·전체 10회·재시도 무의미일 때만 BLOCKED 로 멈춘다. 커버리지 80% 미만은 `TEST` 실패로 센다 — 상세: [done-loop.md](done-loop.md#루프와-멈춤-조건)

STATE.md 갱신: Done Loop 표에 한 줄, AC 체크리스트는 `done.sh` 출력을 옮겨 적는다

> **[확인 게이트 — `full` 모드만, `tdd` 는 묻지 않고 진행]** 평문 질문: "Step 8(Spec 검증) 완료. Step 9(E2E 테스트)를 실행할까요?"

### Step 9: E2E Test

**웹 프로젝트만 실행. `--no-e2e` 플래그 시 스킵.**

**참고**: AC가 사용자 플로우(로그인 → 대시보드 → 결과 확인 등)인 경우, Phase 2 RED 단계에서 실패하는 E2E 또는 통합 레벨 테스트를 먼저 작성할 수 있다. 이 경우 Step 9는 최종 재실행/브라우저 검증만 수행한다.

1. DESIGN.md의 E2E 시나리오를 Playwright 테스트로 작성 (Phase 2에서 미작성 시) — `e2e` 스킬 활용 가능
2. 실행하여 통과 확인

```
PASS → 완료
FAIL → 원인 분류:
  - 구현 버그 → Step 5 회귀
  - Spec 누락 → Step 8 회귀
  - 환경 문제 → 사용자에게 보고
```

### 적대 게이트 ⓑ — Spec-Grounded 최종 코드 리뷰 (공통 하드 게이트: PR 생성 직전)

**사용자가 리뷰를 요청했을 때(`--review` 또는 요청 문장에 "리뷰")만 실행한다 — 요청이 없으면 건너뛰고 완료 보고에 "codex 리뷰 생략(요청 없음)" 한 줄을 남긴다**. 요청했으면 PR 생성 직전에 실행한다. `tdd`/`full` 모드는 Phase 3 전체 PASS 후 여기서 실행하고, `quick` 모드는 [quick-mode.md](quick-mode.md)의 Co-Review 단계가 이 게이트를 겸한다.

사람이 승인한 스펙을 리뷰 컨텍스트에 넣으면 리뷰 제안 채택률이 극적으로 상승한다(spec-grounded review, +90.9%).

1. **codex-advisor**에 위임 (`codex review` 또는 `codex exec --profile review`, read-only — 또는 `/codex:adversarial-review` 커맨드):
   - 입력: **SPEC.md 전문**(AC + Invariants) + `git diff $BASE_BRANCH...HEAD`
   - 리뷰 관점: ① AC·Invariants 위반 여부 ② 스펙에 없는 과잉 구현(YAGNI 위반) ③ 정확성 버그
2. **결과 처리** — [리뷰 결과 수신 규율](brainstorm-design.md#리뷰-결과-수신-규율-게이트-ⓐⓑsdd-리뷰quick-모드-co-review-공통) 준수:
   - **Major** → 각 지적을 코드·SPEC과 대조 검증 후 **검증 소견을 붙여** 평문 질문: "수용(Step 5 회귀·수정) / 기각(사유 기록)". 수정 후 재리뷰 최대 1회
   - **Minor** → 완료 보고에 목록 첨부 (사용자 판단)
3. SDD 모드의 태스크별 리뷰와 별개다 — 태스크 리뷰는 즉시 피드백용(동종 모델), 게이트 ⓑ는 **독립 모델 최종 검증**
4. **codex 미가용 시**: `code-reviewer` 서브에이전트로 폴백 (동종 모델 한계 명시)

STATE.md 갱신: `step: adversarial_b → PASS`

---

## 완료 보고

```
=== Dev Cycle Complete ===
Mode: quick | tdd | full
Feature: [기능명]
Interview: [N라운드, 한 문장: "..."] (quick 모드는 SKIP)
Documents: docs/features/YYYY-MM-DD_기능명/ (quick 모드는 SKIP)
  ✅ BRIEF.md  ✅ PLAN.md  ✅ SPEC.md (AC N개, INV N개)  ✅ DESIGN.md

Implementation (mode: inline | sdd | quick-loop):
  ✅ Tests: N/N passed (coverage XX%)
  ✅ done.sh: exit 0 · DONE N/N · 반복 N회 (출력 전문 첨부 · 동결 뒤 수정 있으면 diff -u 와 이유 · 테스트 diff · MANUAL AC 는 "사용자가 확인할 것"으로 따로)
  직접 확인: bash <done.sh 절대 경로>; echo "exit=$?"   → 기대: DONE N/N, exit=0
  ✅ E2E: N scenarios (또는 SKIP)
  ✅ Build: exit 0
  ✅ Lint: 0 errors
  ✅ Adversarial (공통 하드 게이트): Major N건(수용 N/기각 N)

Commits: N commits on branch feat/xxx
Files changed: N files (+XX, -YY lines)
=== Ready for review ===
```

## 브랜치 마무리

**이해 게이트 (옵션 제시 전 필수)**: 이번 구현의 **비자명한 변경**(새 패턴·까다로운 로직·아키텍처 결정)을 3-5문장으로 워크스루하고 묻는다: "설명이 더 필요한 부분이 있습니까?" — **이해하지 못한 코드는 배포하지 않는다.** 사용자가 요청하면 해당 코드를 함께 읽으며 설명하고, 설명이 안 될 만큼 불투명한 구현이 발견되면 Step 6(리팩터) 회귀를 제안한다. 비자명한 변경이 없으면 "전부 자명한 변경"이라고 한 줄 보고하고 진행.

완료 보고 후 기본 브랜치를 감지하고 상태 요약을 보여준 다음 옵션을 제시한다:

```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git log --oneline "${BASE_BRANCH}..HEAD"    # 커밋 목록
git diff --stat "${BASE_BRANCH}...HEAD"     # 변경 파일 요약
git status -sb                              # dirty tree 확인
```

```
구현이 완료되었습니다. 어떻게 진행할까요?

1. $BASE_BRANCH에 로컬 머지
2. Push 후 PR 생성
3. 브랜치 유지 (나중에 처리)
4. 작업 폐기

어떤 옵션을 선택하시겠습니까?
```

- **Option 1**: `git checkout $BASE_BRANCH && git pull` → merge → **공통 하드 게이트(머지 직전): 전체 테스트 재실행**하여 merge 결과 검증 → 성공 시 브랜치 삭제. 실패 시 머지하지 않고 원인 보고
- **Option 2**: push → `gh pr create` (리뷰를 요청했으면 적대 게이트 ⓑ PASS 후) → 브랜치 유지. `merge` 스킬로 이후 PR 승인·머지·브랜치 정리를 이어갈 수 있다
- **Option 3**: 상태 보고 후 종료
- **Option 4**: 대상 커밋/파일 목록을 보여준 뒤 "discard" 타이핑 확인 후 삭제

STATE.md 갱신: `status: completed`. 세션 종료 전 HANDOFF.md도 최신 상태로 갱신한다 ([SKILL.md 상태 영속화](../skills/cycle/SKILL.md#상태-영속화) 참조).

---

## Phase 4: COMPOUND (학습 환류)

**목표**: 이번 사이클이 다음 사이클을 더 쉽게 만든다 — 작업 단위는 복리로 쌓여야 한다.
브랜치 마무리 후 실행한다. 단독 Phase 0→1 실행(문서만)일 때, 또는 `quick` 모드일 때는 스킵.

### Step 10: 학습 추출

이번 사이클을 되돌아보고 **비자명한 학습만** 추출한다 (1~3개, 없으면 0개 — 억지로 만들지 않는다):

- 예상과 다르게 동작한 것, 디버깅에서 확정한 근본원인
- 이 코드베이스 특유의 재사용 가능한 패턴
- 같은 실수를 반복하지 않을 재발 방지책

**판정 기준**: "다음에 비슷한 작업을 할 때 이 문서가 있으면 시간이 절약되는가?" — No면 버린다.

### Step 11: docs/solutions/ 저장

학습당 1파일: `docs/solutions/<카테고리>/<kebab-슬러그>.md`
카테고리: `best-practices` | `architecture-patterns` | `debugging` | `conventions` (필요 시 추가)

```markdown
---
title: <한 문장 교훈 — 일반화된 명령형으로>
date: YYYY-MM-DD
category: docs/solutions/<카테고리>/
module: <관련 모듈/기능>
problem_type: bug | best_practice | architecture | convention
severity: high | medium | low
applies_when:
  - <이 학습이 적용되는 상황 (다음 사이클의 검색 키)>
tags: [ ... ]
---

# <제목>
## Context (무슨 상황이었나)
## Guidance (무엇을 어떻게 해야 하나 — 번호 목록)
## Why This Matters (지키지 않으면 무엇이 잘못되나)
## When to Apply (언제 적용하나)
```

### Step 12: 상위 환류 제안 (사용자 승인제 — 직접 수정 금지)

학습이 이 프로젝트를 넘어 일반화되면 **제안만** 한다:

| 학습 유형 | 환류 대상 | 방법 |
|----------|----------|------|
| 행동 차단이 필요한 실수 | PreToolUse 훅 | `settings.json` 훅 추가 제안 (hookify 플러그인은 2026-08-30 제거) |
| 사용자 선호·작업 방식 | auto-memory | feedback/project 메모 제안 |
| 프로젝트 규칙 변화 | CLAUDE.md / rules/ | diff 제안 → 승인 후 반영 |
| 이 스킬 자체의 결함 | sos 플러그인 스킬 | 개선 제안 기록만 |

STATE.md Progress Log에 학습 목록(제목·경로)과 환류 제안 처리 결과를 기록한다.

> 읽기 측은 Phase 1 Step 1에 연결되어 있다 — 다음 사이클이 `docs/solutions/`를 fresh glob으로 검색해 계획에 반영한다.
