---
name: setup
description: >-
  Set up a codebase with the bundled sos standards (lint/format/test configs,
  Claude rules and hooks, security templates) through a step-by-step
  conversation that explains every choice before anything is written. Use when
  starting a new project or repo, when the user asks to "셋업", "표준 적용",
  "린터·포매터 설정", "dev-standards 적용", or when sos:cycle finds no
  .dev-standards.manifest. Do not use to set up CI/CD (that is sos:ci).
---

# sos:setup — 대화로 고르는 표준 셋업

`SOS_ROOT` 는 이 스킬의 Base directory 에서 두 단계 위다(`<base>/../..`). 표준 템플릿은 `$SOS_ROOT/standards/`, 적용 스크립트는 `$SOS_ROOT/standards/apply.sh` 다.

**승인 전에는 대상 저장소에 아무것도 쓰지 않는다.** 1~4단계는 `--check` 와 `--dry-run` 만 쓴다.

## 1. 지금 상태 보기

```bash
bash "$SOS_ROOT/standards/apply.sh" --check --target "$PWD"; echo "exit=$?"
```

- exit 0: 이미 적용됐고 최신이다. "건너뛸까, 상위 레벨로 올릴까(`--upgrade`)"만 묻고 끝낸다.
- exit 1: 일부가 낡았거나 빠졌다. OUTDATED·MISSING 목록을 보여 주고 갱신할지 묻는다.
- exit 2 (manifest 없음): 처음 적용이다. 2단계로 간다.

## 2. 언어

프로젝트 파일(`pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `build.gradle(.kts)`, `pom.xml`, `pubspec.yaml`, `Package.swift`, `*.csproj`, `Gemfile`)로 언어를 추정하고 확인받는다. 고를 수 있는 값: python, kotlin-spring, java-spring, typescript-react, go, rust, flutter-dart, swift, csharp-dotnet, ruby-rails.

## 3. 레벨 — 하나씩 설명하고 고르게 한다

기본 추천은 **slim** 이다. 각 레벨이 무엇을 깔고 무엇을 빼는지 아래처럼 풀어서 보여 준다. 정확한 목록은 `bash "$SOS_ROOT/standards/apply.sh" --help` 의 레벨 설명을 읽어 그대로 옮긴다.

- **slim (1~3명)**: Claude 규칙(PRD·SPEC·TDD·보안 + 언어 규칙), 자동 포맷·위험 명령 차단 훅, 팀 공유 권한 설정, `.gitignore`, 언어 린터·포매터. PR 템플릿·가이드 문서는 안 깐다.
- **standard (4~10명)**: slim 전부 + PR 템플릿과 체크리스트, 이슈 폼·라벨·브랜치 규칙 등 GitHub 협업 파일.
- **full·enterprise**: 더 큰 팀용. `--help` 설명을 보여 주고, 개인 프로젝트에는 권하지 않는다고 말한다.

질문 예: "1. 레벨 — slim 으로 할까? 추천 답: slim. 혼자 쓰는 저장소라 PR 체크리스트까지는 짐이 돼. 나중에 `--upgrade` 로 올릴 수 있어."

## 4. 컴포넌트 — 빼고 싶은 것 고르기

레벨에 든 컴포넌트(rules, hooks, settings, templates, security, guides, lang)를 한 줄씩 무엇을 하는지 설명한다. 예: "hooks — 파일을 저장할 때 포매터를 돌리고 `rm -rf /` 같은 명령을 막아." 일부만 원하면 `--only <컴포넌트>` 와 `--pick` 으로 나눠 적용한다.

고른 조합으로 미리보기를 돌려 쓰일 파일 목록을 보여 준다.

```bash
bash "$SOS_ROOT/standards/apply.sh" --dry-run --yes --level <레벨> --lang <언어> --target "$PWD"
```

## 5. 승인 뒤 적용과 확인

사용자가 미리보기를 보고 승인하면 같은 옵션에서 `--dry-run` 만 빼고 실행한다. 그다음 `--check` 가 exit 0 인지 확인하고, `git status --short` 로 새로 생긴 파일을 보여 준다. 커밋은 사용자가 원할 때 한다.

## 끝나는 조건

`apply.sh --check` exit 0, 또는 사용자가 셋업을 건너뛰기로 했다.
