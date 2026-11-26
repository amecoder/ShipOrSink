---
paths:
  - ".github/workflows/**/*.{yml,yaml}"
  - "**/Dockerfile"
  - "**/docker-compose*.yml"
---

# CI/CD Rules

CI/CD must provide fast feedback, secure execution, and repeatable releases.

## Pipeline Shape

- Every PR should run format check, lint, typecheck, tests, and build for changed components.
- Keep the default `GITHUB_TOKEN` permission read-only and grant write permissions per job only when required.
- Use concurrency groups to cancel stale PR runs.
- Cache dependencies using lockfile keys.
- Upload test reports, coverage, and build artifacts only when they help debugging or deployment.

## Security

- Pin third-party actions to immutable SHAs for high-trust repositories.
- Prefer OIDC federation over long-lived cloud credentials.
- Never run untrusted PR input in privileged contexts.
- Run dependency, secret, container, and IaC scanning where the stack applies.
- Generate SBOMs for production artifacts.

## Releases

- Build once and promote the same artifact through environments.
- Separate deploy, migrate, and release-toggle steps when rollback risk is meaningful.
- Database migrations must be backward compatible or have an explicit rollout plan.
- Production deployments need health checks, rollback instructions, and ownership.

## Observability

- CI failures should identify the failing command and artifact location.
- Deployment jobs should emit version, commit SHA, environment, and actor.
- Post-deploy checks should cover the primary user workflow or service health endpoint.
