---
name: regress
description: >-
  Keep regression tests in line with intended spec changes. Conflict mode: when
  a SPEC change delta exists, find old tests that assert the old behavior,
  classify each failure (intended change, regression, unknown), and propose
  rewrite/disable/delete rows in docs/TEST-LEDGER.md for human approval.
  Suite mode: run the full regression suite before ship. Called by sos:spec,
  sos:tc and sos:cycle, or directly ("회귀 테스트 정리", "스펙 바뀌었는데
  옛 테스트 어떻게 해", "회귀 돌려 줘").
---

# sos:regress — 스펙 변경과 회귀 테스트

에이전트는 테스트를 고칠 **제안**만 만든다. 고칠지 정하는 것은 사람이다. 잠금 훅은 `docs/TEST-LEDGER.md` 에서 사람이 승인한 줄이 있는 파일만 열어 주고, 에이전트가 승인 칸(`approved_by`, `approved_at`)을 채우는 편집은 막는다.

## 충돌 모드 — 스펙이 바뀌었을 때

1. **찾기**: SPEC.md `## 변경 델타` 의 옛 AC 번호로 후보를 모은다.
   ```bash
   grep -rn "tc_003\|TC-003" tests/ docs/features/   # 옛 AC 가 AC-03 일 때
   ```
   번호가 안 붙은 옛 테스트는 그 동작을 다루는 모듈의 테스트 파일에서 단언문 키워드로 찾는다.
2. **돌려 보기**: 후보 테스트를 실제로 돌린다. 새 스펙대로 고친 코드가 아직 없으면, 델타에 적힌 새 동작과 단언문을 비교해 판단한다.
3. **나누기**:
   - `INTENDED` — 델타에 적힌 동작 때문에 깨지거나 깨질 테스트. 처리 제안을 쓴다.
   - `REGRESSION` — 델타 밖에서 깨진다. 테스트는 그대로 두고 코드를 고친다.
   - `UNKNOWN` — 판단이 안 선다. 사용자에게 묻는다.
4. **제안 쓰기**: `INTENDED` 마다 TEST-LEDGER 에 줄을 더한다. 승인 칸은 비워 둔다. 처리는 고쳐 쓰기(rewrite) → 내리기(disable) → 지우기(delete) 순서로 우선한다. 지우기는 바로 하지 않고, 먼저 disable 하고 다음 릴리스 뒤 delete 줄을 따로 올린다.
5. **승인 요청**: 사용자에게 번호 붙인 평문 질문으로 각 줄을 보여 주고, 승인하면 사용자가 직접 `approved_by`·`approved_at` 칸을 채우게 한다(에디터에서). 에이전트가 대신 채우지 않는다.
6. **반영**: 승인된 파일만 고친다. 바뀐 AC 에는 새 TC 번호로 테스트를 RED 부터 더한다(`sos:tc` → `sos:build`). TC.md 옛 행은 `retired → 새 번호` 로 둔다.

## TEST-LEDGER.md 형식

```markdown
| test_id | file | ac_old | ac_new | action | reason | classification | approved_by | approved_at | commit | replacement |
|---|---|---|---|---|---|---|---|---|---|---|
| TC-003-1 | tests/test_auth.py | AC-03 | AC-07 | rewrite | SPEC 델타 2026-11-26 (401→429) | INTENDED |  |  |  | TC-007-1 |
```

`file` 은 저장소 루트 기준 경로다. 훅과 PR 직전 검사가 이 칸으로 파일을 맞춘다.

## 묶음 모드 — PR 직전

1. 프로젝트 전체 테스트를 돌린다(선택 실행이 아니라 전부). TC.md 에서 종류가 R 인 테스트가 그 안에 다 들어 있는지 확인한다.
2. 승인 칸이 빈 TEST-LEDGER 줄이 남아 있으면 끝나지 않은 것이다. 사용자에게 알린다.

## 끝나는 조건

충돌 모드: 모든 후보가 분류됐고, `INTENDED` 줄은 승인되어 반영됐거나 사용자가 보류를 정했다. 묶음 모드: 전체 테스트 통과, 승인 안 된 ledger 줄 0.
