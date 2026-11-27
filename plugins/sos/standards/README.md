# sos 표준 — 사용 설명서

이 폴더는 sos 플러그인이 프로젝트에 깔아 주는 품질 표준이다. 언어별 린터·포매터·테스트 설정, Claude Code 규칙과 훅, 보안·CI·GitHub 협업 템플릿, 가이드 문서가 들어 있다.
적용은 `apply.sh` 가 하고, Claude Code 안에서는 `/sos:setup` 이 같은 스크립트를 대화로 불러 준다.

## 설치

sos 플러그인을 설치하면 이 폴더도 함께 받아진다.

```bash
claude plugin marketplace add amecoder/ShipOrSink
claude plugin install sos@shiporsink
```

Claude Code 에서 `/sos:setup` 을 부르면 된다. 무엇을 깔지 하나씩 설명하고 미리보기를 보여 준 뒤, 승인한 것만 쓴다.

셸에서 직접 `apply.sh` 를 돌리려면 이 폴더 경로를 `SOS_STANDARDS` 에 넣는다. 이 설명서와 언어별 README 의 명령은 모두 이 변수를 쓴다.

```bash
# 플러그인 설치본을 쓸 때 (경로에 버전 번호가 들어가서 가장 높은 버전을 고른다)
SOS_STANDARDS="$(ls -d ~/.claude/plugins/cache/shiporsink/sos/*/standards | sort -V | tail -1)"

# 또는 저장소를 직접 받아 쓸 때
git clone https://github.com/amecoder/ShipOrSink ~/.shiporsink
SOS_STANDARDS=~/.shiporsink/plugins/sos/standards
```

필요한 것: `git`, `bash`, `python3`, `jq`(Claude Code 훅이 쓴다). 언어 설정을 검사하려면 그 언어의 도구(ruff, eslint 등)도 있어야 한다.

## 적용 수준 4단계

팀 규모에 맞는 레벨을 고른다. 위 레벨은 아래 레벨을 모두 포함하기 때문에, 혼자 쓰는 저장소라면 slim 으로 시작했다가 팀이 커질 때 `--upgrade` 로 올리면 된다.

| 레벨 | 팀 규모 | 더해지는 것 |
|---|---|---|
| slim | 1~3명 | 언어 린터·포매터, pre-commit, Claude 규칙(PRD·SPEC·TDD·보안·언어), 자동 포맷·위험 명령 차단 훅, 팀 공유 권한 설정, `.gitignore` |
| standard | 4~10명 | PRD·Feature Spec·AI 작업 명세 템플릿, AGENTS·CLAUDE·HANDOFF 템플릿, 코드 리뷰 체크리스트, Git 컨벤션, 보안 자동화, 이슈 폼·라벨·브랜치 ruleset 같은 GitHub 협업 파일 |
| full | 11~30명 | Design Doc, DDD·계층 체크리스트, API·이벤트 계약, SLO·배포 전략·인시던트 관리, CODEOWNERS, 런북 |
| enterprise | 30명 이상 | MSA·이벤트 드리븐·분산 트랜잭션, Contract·Load Testing, Chaos Engineering, 위협 모델링, 온보딩 프로그램 |

정확한 목록은 `bash "$SOS_STANDARDS/apply.sh" --help` 가 보여 준다.

```bash
cd /path/to/my-project
bash "$SOS_STANDARDS/apply.sh" --dry-run --level slim   # 쓰일 파일만 보여 주고 아무것도 쓰지 않는다
bash "$SOS_STANDARDS/apply.sh" --level slim             # 실제 적용 (덮어쓰기 전에 묻는다)
bash "$SOS_STANDARDS/apply.sh" --level standard --upgrade   # slim 에서 standard 의 추가분만
```

## 필요한 것만 골라 적용

`--only` 로 컴포넌트 하나를, `--pick` 으로 그 안의 항목 몇 개를 고른다. 고를 수 있는 컴포넌트 이름은 `--help` 의 「컴포넌트 설명」 절에 설명과 함께 나온다.

```bash
bash "$SOS_STANDARDS/apply.sh" --only hooks                                  # 자동 포맷 + 위험 명령 차단 훅만
bash "$SOS_STANDARDS/apply.sh" --only rules --pick "docker,kubernetes"       # 특정 Claude 규칙만
bash "$SOS_STANDARDS/apply.sh" --only guides --pick "rest-api-design"        # 가이드 문서 하나만
bash "$SOS_STANDARDS/apply.sh" --only github                                 # 이슈 폼·라벨·ruleset·PR 검사
```

## 언어별 설정

언어는 프로젝트 파일(`pyproject.toml`, `package.json`, `go.mod` 등)로 자동 감지되고, `--lang` 으로 직접 정할 수도 있다. 언어별로 들어가는 도구와 수동 적용 방법은 각 폴더 README 에 있다.

| `--lang` 값 | 핵심 도구 | 설명서 |
|---|---|---|
| `python` | Ruff, mypy strict, pre-commit | [python/README.md](python/README.md) |
| `typescript-react` | ESLint 9 Flat, Prettier, Vitest | [typescript-react/README.md](typescript-react/README.md) |
| `go` | golangci-lint v2, gofumpt, gosec, govulncheck | [go/README.md](go/README.md) |
| `rust` | Clippy, rustfmt, cargo-audit, cargo-deny | [rust/README.md](rust/README.md) |
| `kotlin-spring` | detekt, ktlint, JaCoCo, ArchUnit | [kotlin-spring/README.md](kotlin-spring/README.md) |
| `java-spring` | Checkstyle, SpotBugs, JaCoCo | [java-spring/README.md](java-spring/README.md) |
| `flutter-dart` | very_good_analysis, dart format | [flutter-dart/README.md](flutter-dart/README.md) |
| `swift` | SwiftLint, SwiftFormat, Periphery | [swift/README.md](swift/README.md) |
| `csharp-dotnet` | Roslyn Analyzers, SonarAnalyzer, StyleCop, Coverlet | [csharp-dotnet/README.md](csharp-dotnet/README.md) |
| `ruby-rails` | RuboCop, Brakeman, bundler-audit, SimpleCov | [ruby-rails/README.md](ruby-rails/README.md) |

## 품질 기준

모든 언어가 같은 숫자를 쓴다. 정본은 [common/quality-thresholds.yaml](common/quality-thresholds.yaml) 이고, 언어마다 이 숫자를 어떤 도구 설정으로 강제하는지도 그 파일에 적혀 있다.

| 항목 | 기준 |
|---|---|
| 커버리지 | 80% 이상 (바뀐 줄 기준 검사 + 전체가 기준선 아래로 내려가지 않기) |
| 함수 복잡도 | 15 이하 |
| 함수 길이 | 50줄 이하 (Rust 는 100줄 — 위 파일에 예외로 적혀 있다) |
| 파일 길이 | 800줄 이하 |

## 상태 확인과 업데이트

적용하면 대상 프로젝트에 `.dev-standards.manifest` 가 생긴다. 어떤 파일을 어느 원본에서 깔았는지와 그때의 해시를 적은 적용 기록이다. 이 이름은 sos 이전부터 쓰던 것이라, 이미 적용한 프로젝트와 호환되도록 그대로 둔다.

```bash
bash "$SOS_STANDARDS/apply.sh" --check   # OK / OUTDATED / MODIFIED / MISSING 보고, 낡았거나 빠졌으면 exit 1
bash "$SOS_STANDARDS/apply.sh" --diff    # 바뀐 파일의 diff 까지 (파일은 쓰지 않는다)
```

표준 자체를 새 버전으로 받으려면 아래처럼 플러그인을 갱신한다. 갱신한 뒤 `--check` 로 차이를 보고 다시 적용하면 되고, 로컬에서 고친 파일은 덮어쓰지 않는다.

```bash
claude plugin marketplace update shiporsink
claude plugin update sos@shiporsink
```
