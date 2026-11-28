# CHANGELOG

이 저장소의 변경 기록이다. 규칙은 `CLAUDE.md` 「릴리스」에 있다.

- 머지할 때마다 `## 다음 릴리스` 아래 맨 위에 PR 한 줄을 더한다. 굵은 PR 번호, 인라인 코드로 쓴 squash 해시, 커밋 제목 순서이고, 필요하면 아래에 바뀐 점과 후속을 들여 쓴다
- 릴리스할 때 `## 다음 릴리스` 를 `## X.Y.Z (YYYY-MM-DD)` 로 바꾸고, 그 위에 빈 `## 다음 릴리스` 를 새로 둔다. 버전 절의 번호는 `plugins/sos/.claude-plugin/plugin.json` 의 `version` 과 같다(`tests/release.bats`)

## 다음 릴리스

- 아직 없음

## 0.2.1 (2026-11-28)

사용자에게 깔리는 템플릿 주석에서 옛 저장소 이름을 걷어 냈다. 동작은 바뀌지 않는다.

- **#5** `041bc81` 수정: 템플릿 주석의 옛 저장소 이름 정리 (0.2.1)
  - Ruby·Swift·Go·Rust·Python 템플릿 주석 5곳을 sos·ShipOrSink 기준으로, 테스트 주석 3곳 정리
  - 플러그인 버전 0.2.0 → 0.2.1
## 0.2.0 (2026-11-27)

sos 를 원래 저장소 없이 혼자 운영할 수 있게 보강했다(단독 운영 1~4).

- **#4** `a60e5b0` 기능: 릴리스 절차와 버전 0.2.0 (단독 운영 4/4)
  - `plugin.json` 버전 0.1.0 → 0.2.0, CHANGELOG 를 버전 절로 묶음
  - `CLAUDE.md` 「릴리스」 절, `tests/release.bats`(버전과 CHANGELOG 버전 절 일치 검사 4개)
  - 후속: `v0.2.0` 태그와 GitHub 릴리스는 사람 승인 후
- **#3** `2fc599e` 문서: CLAUDE.md·AGENTS.md 추가와 출처 주석 정리 (단독 운영 3/4)
  - 루트 `CLAUDE.md`(저장소 관리 규칙)·`AGENTS.md`(공통 작업 규칙) 추가
  - 원래 저장소 출처 주석 4곳 제거, AGENTS.md 32 KiB 한도 테스트 skip 해제
  - 문서 수치 검사(`tests/claims.bats`)가 루트 문서까지 확인
  - 후속: PR 4 에서 릴리스 절차·CHANGELOG 규칙·플러그인 버전 0.2.0
- **#2** `dbd909c` 기능: 테스트·CI·협업 장치 이식 (단독 운영 2/4)
  - 원래 저장소 bats 34개 파일·픽스처, CI·PR 검사·보안 리뷰·ai-ready 가드·이슈 폼·라벨·ruleset·CODEOWNERS, Renovate(꺼짐)·주간 최신성 검사, 검사 도구 스크립트·pre-commit 을 옮김 (autopilot 제외, 이 저장소에는 `.claude/`·`.githooks/` 를 깔지 않음)
  - 테스트 루트 변수 분리: `REPO_ROOT` = `plugins/sos/standards`, `PROJECT_ROOT` = 저장소 루트
  - `apply.sh --help` 가 색 코드를 글자로 찍던 문제 수정
  - 저장소에 `no-issue`·`large-pr-approved` 라벨 생성
  - 후속: CI bats 잡은 `ubuntu-24.04` 고정(26.04 이전 과제) · AGENTS.md 한도 테스트 skip 은 PR 3 에서 제거 · ruleset 은 아직 GitHub 에 반영하지 않음(`apply-github-settings.sh`)
- **#1** `2502d42` 문서: sos 표준 설치 안내와 설명서 정리 (단독 운영 1/4)
  - 비공개 원래 저장소 clone 안내 92줄을 `$SOS_STANDARDS` 기준으로 교체, `plugins/sos/standards/README.md` 설명서 추가
  - 주석·배너·도움말 이름표를 sos 로 교체 (`.dev-standards.manifest`·`dev-standards:issue-gate` 표식은 호환을 위해 유지)
  - 복사 흔적 `.source-commit`·`.local-changes` 삭제
  - 후속: `apply.sh --help` 색 코드가 글자로 찍히는 기존 문제는 PR 2 에서 고친다. 플러그인 버전은 0.1.0 그대로(PR 4)
## 0.1.0 (2026-11-26)

- `9c87f98` 기능: ShipOrSink(sos) 단계 플러그인 첫 공개
