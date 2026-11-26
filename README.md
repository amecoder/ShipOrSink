# ShipOrSink (`sos`)

기획부터 PR 까지, 단계마다 끝나는 조건이 있는 Claude Code 플러그인이야. 단계 하나가 작은 스킬 하나고, `sos:cycle` 이 순서대로 부른다.

```
setup → spec → tc → build → done → regress → ship        (ci 는 원할 때만)
```

| 스킬 | 하는 일 | 끝나는 조건 |
|---|---|---|
| `sos:setup` | 번들된 dev-standards(린터·포매터·Claude 규칙·훅)를 대화로 골라 적용 | `apply.sh --check` exit 0 |
| `sos:spec` | 캐묻기 → BRIEF·PLAN·SPEC(AC-01..)·DESIGN. 스펙이 바뀌면 변경 델타 | SPEC 승인 |
| `sos:tc` | AC 마다 테스트 케이스 표(TC.md): 정상·경계·오류·회귀 | AC 마다 정상 TC 1개 이상 |
| `sos:build` | RED 테스트 커밋 → 테스트 잠금 → GREEN → REFACTOR | 테스트 통과, 잠금 켜짐 |
| `sos:done` | 완료 조건을 `done.sh` 로 쓰고 exit 0 까지 고치며 반복 | `done.sh` exit 0 |
| `sos:regress` | 스펙 변경과 부딪히는 옛 테스트를 찾아 사람 승인으로 고치기·내리기 | 승인 안 된 ledger 줄 0 |
| `sos:ship` | 전체 검증 + 테스트 약화 검사 + 독립 리뷰 + PR | PR 과 검사 결과 표 |
| `sos:ci` | GitHub Actions 셋업(선택) | 첫 PR 에서 워크플로 실행 |

## 왜 테스트를 잠그나

에이전트에게 "테스트를 고치지 마"라고 말하는 것만으로는 거의 막히지 않는다(METR 2025-06). ImpossibleBench(2025-10)에서는 Claude 계열이 쓴 우회의 대부분이 테스트 수정이었다. 그래서 이 플러그인은 말 대신 장치를 쓴다.

- **테스트 잠금 훅**: RED 커밋 뒤 테스트 파일 편집을 `PreToolUse` 훅이 막는다(exit 2).
- **사람 승인 장부**: `docs/TEST-LEDGER.md` 에서 사람이 `approved_by`·`approved_at` 칸을 채운 파일만 열린다. 에이전트가 그 칸을 채우는 편집도 훅이 막는다.
- **PR 직전 검사**: `scripts/test-diff-check.py <base>` 가 테스트 파일 삭제, skip 추가, 단언문 감소를 찾아 승인 없으면 실패한다.

이 장치는 실수와 게으른 우회를 막는 가드레일이다. 같은 권한의 셸로 작정하고 우회하는 것까지는 못 막으니, PR 에서 ledger diff 를 사람이 읽는 것이 마지막 관문이다.

## 설치

```bash
claude plugin marketplace add amecoder/ShipOrSink
claude plugin install sos@shiporsink
```

필요한 것: `git`, `python3`, `bash`. 셋업은 언어별 도구(ruff, eslint 등)를 쓰므로 그 언어 도구가 설치돼 있어야 한다.

## 사용

```
/sos:cycle 회원가입 API 를 만들어 줘        # tdd 모드(기본)
/sos:cycle quick 로그인 버튼 색 버그 고쳐 줘  # 문서 없이 바로
/sos:setup                                  # 새 저장소에 표준만 깔기
```

스킬 이름을 몰라도 "회원가입 기능 체계적으로 만들어 줘"처럼 말하면 모델이 알맞은 단계를 고른다.

## 테스트

```bash
for t in tests/test-*.sh; do bash "$t" || echo "FAIL $t"; done
```

## 출처

`plugins/sos/standards/` 는 dev-standards 템플릿의 복사본이다(원본 커밋은 `standards/.source-commit`). 단계 구성과 완료 판정 루프는 Anthropic Claude Code best practices, OpenAI harness engineering, mattpocock/skills 의 생각을 참고했다.

## 라이선스

MIT
