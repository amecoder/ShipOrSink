---
name: build
description: >-
  Implement with strict TDD from an approved TC.md: write the failing tests
  (RED), commit them, lock the test files, then implement the minimum code
  (GREEN) and refactor production code. Called by sos:cycle as stage 3, or
  directly when the user asks to implement against existing test cases
  ("TDD 로 구현", "테스트 먼저 쓰고 구현"). Do not use without test cases;
  run sos:tc first.
---

# sos:build — TDD 구현과 테스트 잠금

`SOS_ROOT` 는 이 스킬의 Base directory 에서 두 단계 위다. 자세한 RED·GREEN·REFACTOR 절차는 [implement-tdd.md](../../references/implement-tdd.md) 다.

## 순서

1. **RED**: TC.md 의 행마다 테스트를 쓴다. 테스트 이름에 TC 번호를 넣는다(`test_tc_003_1_...`). 돌려서 **실패 이유가 "기능이 없어서"인지** 확인한다. 문법 오류나 import 오류로 실패하면 RED 가 아니다.
2. **RED 커밋**: 테스트만 커밋한다. 이 커밋 해시를 STATE.md `tests_frozen_at` 에 적는다.
3. **잠금**: 테스트 위치를 잠근다.
   ```bash
   bash "$SOS_ROOT/scripts/sos-lock.sh" on tests/      # 프로젝트 테스트 위치에 맞춰 패턴을 준다
   ```
   잠긴 동안 테스트 파일을 고치거나 지우면 훅이 막는다(exit 2).
4. **GREEN**: 테스트를 통과하는 최소한의 코드를 쓴다.
5. **REFACTOR**: 제품 코드만 정리한다. 테스트는 잠겨 있다.

## 테스트가 막힐 때

훅이 "잠긴 테스트"라고 막으면 우회하지 않는다. 다른 명령이나 다른 도구로 같은 파일을 고치려 하지 않는다.

- 테스트가 스펙과 다르게 보이면 멈추고 사용자에게 묻는다. 스펙이 바뀐 것이면 `sos:regress` 로 가서 TEST-LEDGER 에 줄을 쓰고 사람 승인을 기다린다.
- 새 TC 가 필요하면 `sos:tc` 로 돌아가 표에 행을 더하고, 사용자가 승인한 뒤 잠금을 잠시 풀고(`sos-lock.sh off`) 그 테스트만 더한 다음 다시 잠근다. 푼 이유를 STATE.md 에 남긴다.

## 끝나는 조건

RED 커밋이 있고, 잠금이 켜져 있고(`sos-lock.sh status` exit 0), 테스트가 통과한다. 다음은 `sos:done`.
