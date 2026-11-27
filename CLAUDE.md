# CLAUDE.md

공통 작업 규칙은 [AGENTS.md](AGENTS.md) 에 있다. 이 파일은 ShipOrSink 저장소를 고칠 때 지킬 관리 규칙이다.

## 프로젝트 개요

ShipOrSink 는 Claude Code 플러그인 `sos` 의 저장소다. 기획부터 PR 까지 단계별 스킬(`plugins/sos/skills/`)과, 사용자 프로젝트에 깔아 주는 품질 표준(`plugins/sos/standards/`)을 담는다. 공개 저장소다.

## 구조

```
plugins/sos/
├── skills/        # 단계 스킬 9개 (setup·spec·tc·build·done·regress·ship·ci·cycle)
├── hooks/ scripts/  # 테스트 잠금 훅 · ledger · test-diff-check
├── references/    # 스킬이 읽는 참고 문서
└── standards/     # 사용자 프로젝트에 깔리는 표준 — apply.sh · bootstrap.sh · 언어 10개 · common/
    └── common/    # rules 60개(상시 9) · skills 5개 · hooks · ci/security/github 템플릿 · quality-thresholds.yaml
tests/             # bats(표준 검사) + test-*.sh(스킬·훅 검사) — 플러그인 밖이라 설치본에 안 들어간다
.github/           # 이 저장소의 CI · PR 검사 · 보안 리뷰 · Renovate(꺼짐) · 협업 장치
```

## 개발 규칙

- **고친 뒤 검사**: `bash scripts/install-dev-tools.sh` 로 도구를 깔고, 변경 후 `bats --jobs 8 tests/*.bats` 와 `tests/test-*.sh` 를 통과시킨다. 전체 bats 는 약 6분이다
- **테스트의 두 루트**: `tests/helpers.bash` 의 `REPO_ROOT` 는 `plugins/sos/standards`(템플릿), `PROJECT_ROOT` 는 저장소 루트(운영 파일)다. 새 테스트는 대상에 맞는 쪽을 쓴다
- **이 저장소에는 sos 설정을 깔지 않는다**: `.claude/`·`.githooks/` 를 루트에 두지 않는다. `.github/` 의 협업 파일은 이 저장소용이라 템플릿(`plugins/sos/standards/common/github-templates/`)과 같게 유지한다 — `tests/templates.bats` 의 dogfooding 테스트가 차이를 잡는다
- **프로그램이 읽는 이름은 유지**: `.dev-standards.manifest`, `dev-standards:issue-gate` 는 이미 표준을 적용한 프로젝트와의 호환을 위해 바꾸지 않는다
- **규칙 파일 프론트매터**: 상시 로드가 필요한 것만 `paths:` 를 생략한다(현재 9개, 350줄 예산 — `tests/templates.bats`). 새 규칙은 디렉터리·확장자 패턴을 단다. `**/*` 는 쓰지 않는다
- **스킬 프론트매터는 Agent Skills 규격**: 유효한 YAML, `name` 은 폴더 이름과 같은 소문자·숫자·하이픈 64자 이하, `description` 1~1024자. AGENTS 템플릿과 이 저장소 `AGENTS.md` 는 각각 32 KiB 이하(Codex `project_doc_max_bytes` 기본값) — `tests/templates.bats`
- **도구 버전 핀**: `*_VERSION` 변수 한 곳에 두고 바로 윗줄에 `# renovate: datasource=<id> depName=<name>` 주석을 단다. 스크립트 본문에 버전을 직접 쓰지 않는다(`tests/pins.bats`). sha256 은 Renovate 가 못 바꾸므로 버전이 오르면 사람이 해시를 확인해 넣는다
- **버전은 최신 정식판**: alpha·beta·RC 는 쓰지 않고, 배포 7일이 지난 버전만 쓴다. JDK 는 최신 LTS. 예외: detekt 는 `2.0.0-alpha.6` — 정식 1.23.8 은 JDK 25 의 Gradle 에서 실패한다. 정식 2.0.0 이 나오면 옮긴다
- **워크플로 `uses:` 는 40자 SHA 핀만**: 갱신은 `gh api repos/<o>/<r>/git/ref/tags/<tag>` 로 커밋을 확인해 바꾼다
- **CI bats 잡은 `ubuntu-24.04` 고정**: `ubuntu-latest`(26.04)에서는 SwiftLint 리눅스 바이너리가 `libxml2.so.2` 를 못 찾는다
- **품질 기준**: 커버리지 ≥80%, 복잡도 ≤15, 함수 ≤50줄, 파일 ≤800줄 — 정본 `plugins/sos/standards/common/quality-thresholds.yaml`. 언어 템플릿 설정을 바꾸면 `tests/enforcement*.bats`(한도는 통과, 한도+1 은 실패를 실제 도구로 확인)가 통과해야 한다
- **새 언어 추가**: `plugins/sos/standards/<lang>/bootstrap.sh` + `templates/` + `README.md`, 그리고 `apply.sh` 의 언어 목록
- **표준을 바꾸면 플러그인 버전을 올린다**: 버전이 그대로면 사용자 설치본이 갱신되지 않는다(`plugins/sos/.claude-plugin/plugin.json`)
- **공개 저장소**: 로컬 경로, 개인 정보, 비공개 저장소 이름을 넣지 않는다

## 주요 커맨드

```bash
bats --jobs 8 tests/*.bats                      # 표준 검사 전체
for t in tests/test-*.sh; do bash "$t"; done    # 스킬·훅 검사
bash scripts/install-dev-tools.sh --check       # 검증 도구 현황
bash scripts/local-ci.sh . "$TMPDIR/ci-logs"    # ci.yml 잡을 로컬에서
bash plugins/sos/standards/apply.sh --dry-run --level slim --target /tmp/x   # 적용 미리보기
bash .github/scripts/apply-github-settings.sh --dry-run   # 라벨·ruleset 을 GitHub 에 반영 (dry-run 먼저)
```
