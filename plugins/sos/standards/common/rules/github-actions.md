---
paths:
  - ".github/workflows/**/*.yml"
  - ".github/workflows/**/*.yaml"
  - ".github/actions/**"
---

# GitHub Actions Rules

- Pin all actions to full SHA (not tags): `actions/checkout@<SHA>`
- Set `permissions` at workflow level with minimum required scopes
- Use `concurrency` to cancel redundant runs on same branch
- Reusable workflows (`workflow_call`) for shared CI logic
- Composite actions for shared steps
- Cache dependencies: `actions/cache` or setup-* action built-in cache
- `fetch-depth: 0` only when full history is needed (SonarQube, changelog)

## Security

- Never use `${{ github.event.pull_request.title }}` in `run:` (script injection)
- Use `environment` protection rules for production deployments
- OIDC authentication over long-lived secrets (`aws-actions/configure-aws-credentials`)
- `harden-runner` for runtime security monitoring
- Scorecard for supply chain security assessment

## Structure

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA>
      # ... lint, test, scan
```

## Naming

- Workflow files: `ci.yml`, `deploy.yml`, `release.yml`
- Job names: descriptive, lowercase with hyphens (`lint-and-test`)
- Step names: start with verb (`Run tests`, `Build image`, `Deploy to staging`)

## Forbidden

- `permissions: write-all` (use minimum scope)
- Action tags without SHA pinning (`actions/checkout@v4` alone)
- Secrets in workflow logs (`echo $SECRET`)
- `pull_request_target` with `actions/checkout` of PR head (code injection risk)
- Auto-merge without required checks
