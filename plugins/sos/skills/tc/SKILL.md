---
name: tc
description: >-
  Design test cases from a SPEC's acceptance criteria into a TC.md table
  (normal, boundary, error, regression cases, each linked to an AC and to a
  test location) before any implementation. Called by sos:cycle as stage 2, or
  directly when the user asks for test case design ("테스트 케이스 설계",
  "TC 뽑아줘", "어떤 걸 테스트해야 해"). Do not use to write the test code
  itself (that is sos:build).
---

# sos:tc — 테스트 케이스 설계

SPEC.md 옆에 `TC.md` 를 쓴다. 테스트 코드는 쓰지 않는다. 코드는 `sos:build` 가 이 표를 보고 쓴다.

## 칸

| TC ID | AC | 종류 | 입력/조건 | 기대 결과 | 테스트 위치 | 상태 |
|---|---|---|---|---|---|---|
| TC-003-1 | AC-03 | N | 있는 사용자, 틀린 비밀번호로 `POST /login` | 401, 토큰 없음, 본문 `invalid_credentials` | `tests/test_auth.py::test_tc_003_1` | todo |
| TC-003-2 | AC-03 | E | 없는 이메일 + 아무 비밀번호 | 401, TC-003-1 과 같은 본문 | `tests/test_auth.py::test_tc_003_2` | todo |
| TC-003-3 | AC-03 | B | 빈 비밀번호 / 최대 길이+1 | 401(400 이면 AC 에 적는다), 서버 오류 아님 | `tests/test_auth.py::test_tc_003_3` | todo |

- **종류**: N 정상, B 경계, E 오류, R 회귀.
- **기대 결과**는 상태 코드, 메시지, 저장된 값처럼 눈으로 확인할 수 있는 것으로 쓴다.
- **테스트 위치**는 `파일::테스트 이름` 이다. 테스트 이름에 TC 번호를 넣어서 `grep TC-003` 하나로 문서와 코드를 오갈 수 있게 한다.
- **상태**: todo, pass, retired(→ 새 TC 번호).

## 몇 개를 뽑나

- AC 마다 N 1개는 꼭 둔다.
- 입력에 범위나 길이 한계가 있으면 경계마다 B 2개(경계 안, 바로 밖)를 둔다.
- AC 에 실패 경로가 적혀 있으면 E 1개씩 둔다. 입력 조합이 여럿이면 결정표로 행을 뽑는다.
- 그 밖의 오류 추측은 후보 3개까지만 제안하고 사용자가 고른 것만 넣는다. 과하게 뽑으면 검토를 못 한다.
- R 은 버그가 나왔을 때 그 버그를 재현하는 TC 로만 더한다.
- TC 하나는 동작 하나만 본다. 이름에 "그리고"가 들어가면 쪼갠다.

## 번호 규칙

- 번호는 `TC-<AC번호>-<순번>` 이고 다시 쓰지 않는다.
- AC 가 바뀌면 새 TC 를 만들고, 옛 행은 지우지 않고 상태를 `retired → TC-007-1` 로 바꾼다.
- SPEC 에 변경 델타가 있으면, 이 표를 고치기 전에 `sos:regress` 충돌 점검이 끝났는지 확인한다.

## 끝나는 조건

AC 마다 N 이 1개 이상 있고, 모든 행에 테스트 위치가 있고, 사용자가 표를 승인했다.
