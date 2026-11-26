---
name: done
description: >-
  Define a completion condition as an executable done.sh (one check per
  acceptance criterion), freeze it, and loop fix → build/lint/test → done.sh
  until it exits 0, stopping on no progress (same failure 3 times), 10
  iterations, or a broken checker. Called by sos:cycle as stage 4, or directly
  for any task with a clear finish line ("완료 조건 정해서 될 때까지",
  "이 테스트 다 통과할 때까지 고쳐 줘"). Do not use for open-ended
  exploration with no checkable outcome.
---

# sos:done — 완료 조건 루프

계약, 예시 스크립트, 기준선과 동결, 멈춤 조건, 약화 금지 규칙, 무인 실행(ralph-loop)은 모두 [done-loop.md](../../references/done-loop.md) 에 있다. 이 문서를 그대로 따른다.

## 이 플러그인에서 달라지는 것

- **AC 출처**: `tdd`·`full` 은 SPEC.md 의 AC 와 TC.md 를 쓴다. AC 하나에 `check` 한 줄을 두고, 그 줄은 그 AC 의 TC 테스트들을 돌린다. 예: `check AC-03 uv run --frozen pytest -q -k "tc_003"`.
- **quick**: 요청에서 AC 를 뽑아 `.git/sos/done/<브랜치>/done.sh` 에 쓴다. 위치 계산 스니펫은 done-loop.md 계약 절에 있다.
- **테스트는 잠겨 있다**: 루프 안에서 실패를 고칠 때 제품 코드만 고친다. 테스트를 고쳐야 할 것 같으면 멈추고 `sos:regress` 로 간다.
- **멈추면**: BLOCKED 보고에 Done Loop 표, 마지막 done.sh 출력, 시도한 가설 목록을 붙인다.

## 끝나는 조건

`done.sh` 가 exit 0 이고, 그 출력 전문(`DONE n/n` 포함)이 보고에 있다.
