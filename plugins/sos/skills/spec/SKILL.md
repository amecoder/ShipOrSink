---
name: spec
description: >-
  Turn a feature request into approved planning docs (BRIEF, PLAN, SPEC with
  numbered acceptance criteria AC-01.., DESIGN) by interviewing for what is
  undecided. When an existing SPEC changes, record a change delta of the
  behaviors that change. Called by sos:cycle as stage 1, or directly when the
  user wants only the spec ("스펙 뽑아줘", "요구사항 정리", "기획만",
  "SPEC 만들어줘"). Do not use for small fixes whose requirement is obvious.
---

# sos:spec — 기획과 스펙

## 순서

1. **캐묻기**: `grilling` 스킬이 있으면 `Skill` 도구로 부른다. 없으면 [brainstorm-design.md](../../references/brainstorm-design.md#phase-0-brainstorm-기획-브레인스토밍--briefmd) 의 인터뷰를 따른다. 사실은 코드와 문서에서 직접 찾고, 결정만 사용자에게 묻는다.
2. **문서**: [brainstorm-design.md Phase 1](../../references/brainstorm-design.md#phase-1-design-문서-생성) 대로 `docs/features/<YYYY-MM-DD>_<기능>/` 에 BRIEF·PLAN·SPEC·DESIGN 을 쓰고 섹션별 승인을 받는다.
3. **AC 쓰기**: SPEC.md 의 AC 는 `AC-01` 부터 번호를 붙이고, 관찰 가능한 결과로 쓴다. 예: "틀린 비밀번호로 로그인하면 401 과 `invalid_credentials` 를 돌려준다". 구현 방법은 쓰지 않는다. 번호는 다시 쓰지 않는다.

## 기존 스펙이 바뀔 때 — 변경 델타

이미 SPEC.md 가 있으면 SPEC.md 맨 아래 `## 변경 델타` 표에 바뀌는 동작을 한 줄씩 적는다.

| 날짜 | AC | 변경 | 이유 |
|---|---|---|---|
| 2026-11-26 | AC-03 → AC-07 | 401 대신 429(잠금 후) | 무차별 대입 막기 |

- 바뀐 AC 는 지우지 않고 `~~AC-03~~ → AC-07` 로 남기고 새 번호를 준다.
- 델타가 하나라도 있으면 다음 단계 전에 `sos:regress` 의 충돌 점검을 부른다. 옛 테스트와 부딪히는 것을 구현 전에 찾기 위해서다.

## 끝나는 조건

SPEC.md 의 모든 AC 가 관찰 가능한 결과로 적혔고, 사용자가 SPEC 을 승인했다. 델타가 있으면 `sos:regress` 충돌 점검까지 끝났다.
