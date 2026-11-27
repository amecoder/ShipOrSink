# CHANGELOG

이 저장소의 변경 기록이다. 머지할 때마다 위에 한 줄씩 더한다.

## 2026-11-27

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
- `9c87f98` 기능: ShipOrSink(sos) 단계 플러그인 첫 공개
