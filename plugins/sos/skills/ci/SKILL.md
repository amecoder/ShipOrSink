---
name: ci
description: >-
  Optional CI setup: add a GitHub Actions workflow (tests, lint, security scan
  on every PR) from the bundled templates, explaining each job before writing.
  Use only when the user asks for CI/CD ("CI 붙여 줘", "GitHub Actions 설정",
  "PR 마다 테스트 돌게"). Not part of the default sos:cycle flow. Deployment
  pipelines are out of scope.
---

# sos:ci — CI 셋업 (원할 때만)

`SOS_ROOT` 는 이 스킬의 Base directory 에서 두 단계 위다. 템플릿은 `$SOS_ROOT/standards/common/ci-templates/` 에 있다: `ci-python.yml`, `ci-typescript.yml`, `ci-go.yml`, `ci-kotlin.yml`, `ci-docker.yml`, `ci-api-contract.yml`.

## 순서

1. 언어에 맞는 템플릿을 고르고, 안의 잡(job)마다 무엇을 하는지 한 줄씩 설명한다. 예: "lint — PR 마다 ruff 로 코드 규칙을 검사해."
2. 프로젝트에 맞춰 바꿀 곳(파이썬 버전, 테스트 명령, 기본 브랜치)을 보여 주고 확인받는다.
3. 승인 뒤 `.github/workflows/ci.yml` 로 쓴다. 이미 같은 이름이 있으면 덮지 않고 차이를 보여 준다.
4. 템플릿 안 액션이 버전이나 SHA 로 고정돼 있는지 확인한다. `@main`, `@latest` 는 고정 값으로 바꾸자고 제안한다.
5. 다음 PR 에서 워크플로가 실제로 도는지 사용자와 함께 확인한다.

배포(서버, 스토어, 클라우드)는 대상마다 달라서 이 스킬이 다루지 않는다.

## 끝나는 조건

워크플로 파일이 있고, 첫 PR 에서 그 워크플로가 돌았다.
