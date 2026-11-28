# HANDOFF.md

## ▶ 지금 할 일 (2026-11-27 작성)

sos 를 원래 저장소(비공개 dev-standards) 없이 혼자 운영할 수 있게 보강한다. 원래 저장소는 프리징된다.
조사·계획 정본: `docs/reports/2026-11-27_sos-단독-운영-보강-조사.md` — 먼저 읽는다.

**단독 운영 보강 PR 4개 모두 머지 (2026-11-28).** `v0.2.0` 태그·GitHub 릴리스 생성(2026-11-28, `a60e5b0`). 이어서 PR #5(squash `041bc81`)로 템플릿 주석의 옛 저장소 이름을 정리하고 `v0.2.1` 릴리스. 다음 릴리스 절차는 `CLAUDE.md` 「릴리스」.

### 사용자 결정 (2026-11-27)
- PR 네 개로 나눠 순서대로 진행: 1 설치 안내·설명서 → 2 테스트·CI·협업 장치 → 3 CLAUDE.md·AGENTS.md → 4 유지보수
- `.dev-standards.manifest`·`dev-standards:issue-gate` 같은 프로그램용 이름은 유지, 주석·라벨 이름표만 sos 로
- 협업 장치(이슈 폼·라벨·ruleset·CODEOWNERS·PR 템플릿·PR 정책·보안 리뷰 게이트·ai-ready 가드)는 PR 2 에 같이 넣는다
- `.clinerules-*` 는 옮기지 않는다
- Renovate 설정(`renovate.json`·`renovate.yml`)은 PR 4 가 아니라 PR 2 에서 같이 넣는다(2026-11-27 사용자 결정) — PR 2 판정 기준 "실패 61 이하"는 그대로, `template-freshness.yml` 도 PR 2 로 당겼다(같은 날 결정) — PR 4 에는 릴리스 절차·CHANGELOG 규칙만 남는다
- 원래 저장소의 이력 문서는 옮기지 않는다 — 이 저장소는 공개라 비공개 내용을 넣지 않는다
- sos 설정은 글로벌 `~/.claude` 와 따로 `plugins/sos/standards/common/` 한 곳에만 둔다. ShipOrSink 저장소 자신에게는 `.claude/`·`.githooks/` 를 깔지 않는다 — dogfooding 테스트에서 그 비교를 지웠다. `.github/` 협업 파일은 이 저장소용이라 넣고, 템플릿과의 비교도 남긴다

### 진행 상태
| PR | 브랜치 | 상태 |
|---|---|---|
| 1 | `feat/standalone-1-install-docs` | ✅ PR #1 머지 (squash 2502d42, 2026-11-27) — 안내 92→0줄, `standards/README.md` 설명서, 이름표·복사 흔적 정리, 테스트 4/4 |
| 2 | `feat/standalone-2-tests-ci` | ✅ PR #2 머지 (squash dbd909c, 2026-11-27) — 테스트·CI·협업 장치·Renovate·최신성 검사 이식. 첫 Actions 실행에서 bats 9건 실패 → 러너 24.04 고정·Go·TS·Python 테스트 결함 수정 후 16개 체크 전부 통과. Fable 5.2 전수 리뷰 [필수] 2건 반영 |
| 3 | `feat/standalone-3-agent-docs` | ✅ PR #3 머지 (squash 2fc599e, 2026-11-27) — CI 17개 통과, 루트 CLAUDE.md(관리 규칙)·AGENTS.md(공통 규칙), 출처 주석 4 → 0, AGENTS 한도 테스트 skip 제거 후 통과, 문서 수치 검사가 루트 문서까지 보게(QUOTE_COUNT 14/16/13/10) |
| 4 | `feat/standalone-4-maintenance` | ✅ PR #4 머지 (squash a60e5b0, 2026-11-28) — 버전 0.2.0, CHANGELOG 버전 절, CLAUDE.md 「릴리스」, `tests/release.bats` 4/4. CI 17개 통과 |

### 원본 파일 가져오기
원래 저장소의 로컬 clone 에서 커밋 `3d0eb76` 기준으로 가져온다 — `git -C <원래 저장소 clone> show 3d0eb76:<파일>`. clone 위치는 이 머신의 작업 폴더에서 찾는다(공개 저장소라 경로를 적지 않는다)

### 원래 저장소에서 이어 받을 메모
원래 저장소 `HANDOFF.md` 의 「작업 대기열」(T1·T2 등, 모두 ✅)에 각 작업의 「남은 일」과 「함정」이 있다 — 예: 커버리지 게이트가 Rust·Java·Kotlin·Swift 엔 전체 80% 검사가 없음, 전체 bats 는 `--jobs 8` 로 약 6분, 이 머신에 Gradle·cargo-llvm-cov 없음. PR 2 를 시작하기 전에 읽는다

### PR 1 에서 정한 것 (다음 PR 이 알아야 할 것)
- 안내문의 표준 폴더 경로는 `$SOS_STANDARDS` 변수로 쓴다. 값 구하는 법은 `plugins/sos/standards/README.md` 「설치」 한 곳에만 둔다
- 일부러 남긴 `dev-standards`: `.dev-standards.manifest`, `dev-standards:issue-gate`, Grafana 대시보드 `tags` 값, setup 스킬의 트리거 문구 "dev-standards 적용"
- 원래 있던 문제 발견: `apply.sh --help` 가 색 코드(`\033[…`)를 81곳에서 글자 그대로 찍는다(unquoted heredoc 을 `cat` 으로 출력). PR 2 에서 테스트와 함께 고친다(2026-11-27 사용자 결정)
- 플러그인 버전은 PR 4 에서 0.2.0 으로 올렸다(2026-11-27 사용자 결정)

### 나중에 할 것 (PR 2 첫 CI 에서 나옴)
- CI bats 잡을 `ubuntu-24.04` 로 고정했다. `ubuntu-latest`(=26.04, 2026-11)에서는 SwiftLint 리눅스 바이너리가 `libxml2.so.2` 를 못 찾고, pytest 단계 2개가 `PYTHONPATH=src` 를 주고도 fixture 패키지를 못 불러왔다(원인 미확인 — pipx 의 격리 실행 추정). 26.04 로 옮기려면 이 둘을 먼저 고친다
- 같은 이유로 사용자에게 깔리는 CI 템플릿(`common/ci-templates/*.yml`)도 `ubuntu-latest` 라 26.04 에서 같은 문제가 날 수 있다 — 확인 필요

### 결정 대기
- architecture 그림(저장소 구조도·강제 장치 흐름 등)을 새 저장소 설명용으로 다시 그릴지 — 원래 저장소 그림은 이력 문서로 묶어 옮기지 않았다
- ruleset(main-protection-solo)은 보류(2026-11-28 사용자 결정) — 걸면 머지 뒤 main 직접 문서 커밋이 막힌다. 라벨 11개만 반영했다

### 로컬 환경 메모
- 이 머신에서 Dart 훅 검사(exit 126)와 Ruby 검사(`bundle install` 실패) 10개가 main 에서도 실패한다. CI 에서는 통과 — 원인 미확인

### 주의
- 커밋·push·PR 은 사용자가 요청할 때만
- 원래 저장소 세션의 가드는 다른 저장소 push 를 막는다 — 이 저장소 작업은 이 폴더에서 연 세션에서 한다
