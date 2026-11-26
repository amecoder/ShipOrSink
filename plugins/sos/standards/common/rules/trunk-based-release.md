---
paths:
  - ".github/**"
  - "**/CHANGELOG.md"
  - "**/release*/**"
  - "**/releases/**"
  - "**/flags/**"
  - "**/feature_flags/**"
  - "**/featureflags/**"
  - "docs/release/**"
---

# Trunk-Based Development & Release Governance Rules

Optimize for short-lived branches, continuous integration, safe rollouts, and reversible releases.

## Branching

- `main` (or `trunk`) is always releasable. Production deploys come from trunk or a release branch cut from trunk.
- Feature work happens on short-lived branches (target: < 24h, max 3 days) merged via PR with required checks.
- Long-running parallel branches are avoided; if needed, merge from trunk daily.
- Incomplete features ship behind feature flags, not behind branches.

## CI Gates (required before merge)

- Build, lint/format, type check, unit tests, integration tests for changed modules.
- Static security checks (SAST, secret scan, dependency audit) and license check.
- Architecture fitness functions for the affected modules.
- Coverage threshold on changed lines.
- For risky areas (auth, payments, data migration): smoke tests, contract tests, or replay tests.

## Release Pipeline

- Continuous delivery to a staging environment on every merge to trunk.
- Production deploy is a deliberate action: scheduled, button-click, or auto-promoted after canary metrics pass.
- Deployment uses progressive delivery (canary, blue-green, or staged rollout) when error budget or impact warrants it.
- Every release has: change list, rollback procedure, owner, observability links, and feature flag state.

## Feature Flags

- New user-visible behavior is gated behind a flag with default OFF in production until enabled by an explicit ramp.
- Flags have an owner, expiration date, and removal task.
- Stale flags older than the agreed window (e.g., 60 days) are cleaned up; failing this should be flagged in tech debt review.
- Kill-switch flags are documented in the runbook for fast disable.

## Release Readiness

- Use the Release Readiness Checklist (see template) for any change touching: schema, money, auth, public API, infra, data privacy.
- Database migrations are expand → migrate → contract; never drop a column in the same release that adds it.
- Backwards-incompatible API or event changes follow the deprecation policy (header + sunset timeline).
- Rollback plan is described and verified before production rollout.

## Observability At Release

- Define the metrics and alerts that will detect a bad release within 15 minutes (latency, error rate, business KPI).
- Compare canary vs control on those metrics before full rollout.
- Roll back automatically (or manually with a clear runbook) when budgets are breached.

## Review Checklist

- Branch lifetime is short and PR is small enough to review.
- All required CI gates passed; suppressions are justified in the PR description.
- Release readiness checklist is attached for risky changes.
- Feature flag state and rollout plan are documented.
- Rollback path is reversible without data loss.
