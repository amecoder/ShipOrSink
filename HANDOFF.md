# HANDOFF.md

## ▶ 지금 할 일 (2026-11-27 작성)

sos 를 원래 저장소(비공개 dev-standards) 없이 혼자 운영할 수 있게 보강한다. 원래 저장소는 프리징된다.
조사·계획 정본: `docs/reports/2026-11-27_sos-단독-운영-보강-조사.md` — 먼저 읽는다.

**다음: PR 2** — main 에서 `feat/standalone-2-tests-ci` 를 만들고 시작한다. 시작 전에 아래 「원래 저장소에서 이어 받을 메모」를 읽고, 이식본 bats 실패 수(기준선 93)를 다시 잰다.

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
| 2 | `feat/standalone-2-tests-ci` | 구현·검증 끝, 커밋 전 — 운영 파일·Renovate·최신성 검사 이식, 테스트 루트 변수 분리(`REPO_ROOT`=표준 · `PROJECT_ROOT`=저장소), `--help` 색 코드 수정. bats 실패 97 → 63 (샌드박스): 도구 다운로드 막힘 61 + 샌드박스 gh 1(밖에서 통과) + AGENTS 한도 1(PR 3) · pins 5/5 |
| 3 | `feat/standalone-3-agent-docs` | ⬜ |
| 4 | `feat/standalone-4-maintenance` | ⬜ |

### 원본 파일 가져오기
원래 저장소의 로컬 clone 에서 커밋 `3d0eb76` 기준으로 가져온다 — `git -C <원래 저장소 clone> show 3d0eb76:<파일>`. clone 위치는 이 머신의 작업 폴더에서 찾는다(공개 저장소라 경로를 적지 않는다)

### 원래 저장소에서 이어 받을 메모
원래 저장소 `HANDOFF.md` 의 「작업 대기열」(T1·T2 등, 모두 ✅)에 각 작업의 「남은 일」과 「함정」이 있다 — 예: 커버리지 게이트가 Rust·Java·Kotlin·Swift 엔 전체 80% 검사가 없음, 전체 bats 는 `--jobs 8` 로 약 6분, 이 머신에 Gradle·cargo-llvm-cov 없음. PR 2 를 시작하기 전에 읽는다

### PR 1 에서 정한 것 (다음 PR 이 알아야 할 것)
- 안내문의 표준 폴더 경로는 `$SOS_STANDARDS` 변수로 쓴다. 값 구하는 법은 `plugins/sos/standards/README.md` 「설치」 한 곳에만 둔다
- 일부러 남긴 `dev-standards`: `.dev-standards.manifest`, `dev-standards:issue-gate`, Grafana 대시보드 `tags` 값, setup 스킬의 트리거 문구 "dev-standards 적용", 출처 주석 4줄(`dev-standards common/`·`tests/` — PR 3 범위)
- 원래 있던 문제 발견: `apply.sh --help` 가 색 코드(`\033[…`)를 81곳에서 글자 그대로 찍는다(unquoted heredoc 을 `cat` 으로 출력). PR 2 에서 테스트와 함께 고친다(2026-11-27 사용자 결정)
- 플러그인 버전은 0.1.0 그대로 — 버전 올리기는 PR 4 의 릴리스 절차에서 정한다

### PR 3 이 이어받을 것 (PR 2 리뷰에서 나옴)
- `tests/templates.bats` 의 AGENTS.md 한도 테스트에 넣은 `skip "repo AGENTS.md not added yet (PR 3)"` 를 지운다
- `tests/claims.bats` 의 `DOCS` 는 `REPO_ROOT`(표준 폴더) 기준이라 루트 `CLAUDE.md`·`AGENTS.md` 를 못 본다 — 루트 문서를 대상에 넣고 `QUOTE_COUNT` 를 다시 맞춘다

### 주의
- 커밋·push·PR 은 사용자가 요청할 때만
- 원래 저장소 세션의 가드는 다른 저장소 push 를 막는다 — 이 저장소 작업은 이 폴더에서 연 세션에서 한다
