---
name: ship
description: >-
  Final verification and pull request: build, type check, lint, full tests,
  done.sh exit 0, the test-weakening diff check against the base branch, an
  independent reviewer subagent, then a PR whose body carries a table of check
  results. Called by sos:cycle as the last stage, or directly when work is done
  and the user wants a PR ("PR 만들어 줘", "마무리하고 올려 줘"). Asks before
  pushing or creating the PR. Does not merge.
---

# sos:ship — 검증하고 PR 까지

`SOS_ROOT` 는 이 스킬의 Base directory 에서 두 단계 위다. 검증 단계 세부는 [verify-compound.md](../../references/verify-compound.md) 다.

## 순서

1. **검증 묶음**: 빌드, 타입 검사, 린트, 전체 테스트를 돌린다. 하나라도 실패하면 `sos:done` 루프로 돌아간다.
2. **완료 조건**: `done.sh` 를 다시 돌려 exit 0 을 확인한다.
3. **회귀**: `sos:regress` 묶음 모드를 부른다.
4. **테스트 약화 검사**:
   ```bash
   python3 "$SOS_ROOT/scripts/test-diff-check.py" origin/main   # 기준 브랜치에 맞춘다
   ```
   exit 1 이면 PR 을 만들지 않는다. 출력의 `BLOCK` 줄(삭제, skip 추가, 단언문 감소)마다 `sos:regress` 로 ledger 승인을 받아야 한다.
5. **독립 리뷰**: 새 컨텍스트 서브에이전트에게 SPEC.md 와 `git diff <기준>...HEAD` 를 주고 "모든 AC 가 구현됐고 TC 의 경계·오류 경우에 테스트가 있는지"를 보게 한다. 스타일 지적은 건너뛰게 한다. `--review` 면 독립 모델(예: codex)의 적대 리뷰를 더한다 — [verify-compound.md](../../references/verify-compound.md#적대-게이트-ⓑ--spec-grounded-최종-코드-리뷰-공통-하드-게이트-pr-생성-직전).
6. **PR**: 푸시와 PR 생성 전에 사용자에게 한 번 묻는다. 본문 맨 위에 쉬운 말 요약 2~3줄을 두고, 아래 표를 붙인다.

   | 검사 | 명령 | 결과 |
   |---|---|---|
   | 테스트 | `pytest -q` | 42 passed |
   | 완료 조건 | `bash done.sh` | DONE 5/5, exit 0 |
   | 테스트 약화 | `test-diff-check.py origin/main` | OK |
   | 리뷰 | 독립 서브에이전트 | 지적 0건 |

7. **잠금 풀기**: PR 이 열리면 `bash "$SOS_ROOT/scripts/sos-lock.sh" off`. 리뷰 반영으로 다시 고칠 때는 `sos:build` 가 다시 잠근다.
8. **학습 남기기**(선택): [verify-compound.md Phase 4](../../references/verify-compound.md#phase-4-compound-학습-환류) 대로 `docs/solutions/` 에 배운 것을 남긴다.

머지는 하지 않는다. 머지는 사용자가 한다.

## 끝나는 조건

PR 이 열렸고, 본문에 검사 결과 표가 있고, 약화 검사가 OK 다.
