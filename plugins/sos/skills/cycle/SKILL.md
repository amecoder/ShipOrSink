---
name: cycle
description: >-
  Ship Or Sink development cycle — guides a substantial build from plan to PR by
  calling the sos stage skills in order: setup → spec → tc → build → done →
  regress → ship. Use PROACTIVELY when the user asks to build something
  substantial: a new feature, API endpoint, screen, module, auth/payment flow,
  or a refactor spanning several files ("체계적으로 개발", "tdd 사이클",
  "기능 만들어 줘", "자동으로 구현해줘", "단계별로 확인하며"). Modes: tdd
  (default), quick (unattended, no docs), full (confirm every step). Do NOT use
  for typos, one-line edits, explanations, commits, or debugging a single error.
---

# sos:cycle — 단계 길잡이

자기 일은 순서를 정하고 단계 스킬을 부르는 것뿐이다. 각 단계의 절차는 그 스킬이 갖고 있다. 단계 스킬은 `Skill` 도구로 `sos:<이름>` 을 불러 실행한다.

## 단계와 끝나는 조건

| 순서 | 스킬 | 끝나는 조건 |
|---|---|---|
| 0 | `sos:setup` | `apply.sh --check` exit 0, 또는 사용자가 셋업을 건너뛰기로 했다 |
| 1 | `sos:spec` | SPEC.md 의 모든 AC 가 관찰 가능한 결과로 적혔고 사용자가 승인 |
| 2 | `sos:tc` | AC 마다 정상 TC 1개 이상, TC.md 모든 행에 테스트 위치 |
| 3 | `sos:build` | RED 커밋이 있고, 테스트가 잠겼고, 구현 후 테스트 통과 |
| 4 | `sos:done` | `done.sh` exit 0 |
| 5 | `sos:regress` | 회귀 묶음 통과, 승인 안 된 ledger 줄 0 |
| 6 | `sos:ship` | PR 이 열렸고 본문에 검사 결과 표가 있다 |

`sos:ci` 는 이 흐름 밖이다. 사용자가 CI/CD 를 원할 때만 부른다.

## 모드

| 모드 | 부르는 순서 | 멈추는 곳 |
|---|---|---|
| `tdd` (기본) | 0 → 1 → 2 → 3 → 4 → 5 → 6 | 문서 승인(SPEC·TC·DESIGN)과 PR 생성 직전만 |
| `quick` | 0(점검만) → `sos:done` 이 요청에서 AC 를 뽑아 done.sh 작성 → 3 → 4 → 5 → 6 | PR 생성 직전만. 문서를 쓰지 않는다 — [quick-mode.md](../../references/quick-mode.md) |
| `full` | `tdd` 와 같다 | 단계 안의 모든 스텝마다 번호 붙인 평문 질문으로 확인 |

모드를 말하지 않았으면 추정해서 제안한다. 1~2개 파일, 요구가 자명하면 `quick`. 새 기능이나 요구가 흐리면 `tdd`. "천천히", "하나씩", "위험하니"가 있으면 `full`.

요청이 "스펙만", "기획만"이면 1(spec)에서 끝낸다.

## 공통 원칙

1. 사전 점검: `git status -sb && git branch --show-current`. main/master 면 기능 브랜치를 만들자고 제안하고 멈춘다. 커밋 안 된 변경이 있으면 stash 나 커밋을 제안한다.
2. 완료는 증거로만 판정한다. 모델이 체크한 체크박스는 근거가 아니다. `done.sh` exit 0 과 명령 출력이 근거다.
3. 테스트는 RED 커밋 뒤 잠긴다(`sos:build`). 스펙과 테스트가 부딪히면 테스트를 고치지 말고 `sos:regress` 로 가서 사람 승인을 받는다.
4. 같은 실패가 진척 없이 3회면 멈춘다 — [debugging.md](../../references/debugging.md).
5. 물어야 하면 번호 붙인 평문 질문으로 한 번에 묻고, 질문마다 추천 답을 붙인다.
6. 프로젝트 저장소의 규칙(CLAUDE.md·.claude/rules)이 이 플러그인 설명과 다르면 프로젝트 쪽을 따른다.

## 상태

- `STATE.md`(`docs/features/<날짜>_<기능>/STATE.md`, quick 은 `.git/sos/done/<브랜치>/STATE.md`)에 `mode`, `stage`, `done`, `lock` 을 단계마다 갱신한다. `--resume` 이면 이 파일을 읽고 멈춘 단계부터 다시 부른다.
- 프로젝트에 `HANDOFF.md` 가 있으면 단계가 끝날 때마다 진행 상태를 적는다. 단계 경계가 `/clear` 하기 좋은 지점이다.

## 플래그

| 플래그 | 동작 |
|---|---|
| `--resume` | STATE.md 를 읽고 멈춘 단계부터 |
| `--no-setup` | 0단계를 건너뛴다 |
| `--sdd` | `sos:build` 를 태스크별 서브에이전트로 — [implement-tdd.md](../../references/implement-tdd.md#sdd-모드-서브에이전트-기반) |
| `--review` | `sos:ship` 에서 독립 모델 적대 리뷰를 추가로 돌린다 |
