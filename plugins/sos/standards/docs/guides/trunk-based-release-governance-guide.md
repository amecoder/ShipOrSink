# Trunk-Based Development & Release Governance Guide

## Goal

Ship small changes continuously with high confidence. Keep main green, branches short-lived, releases reversible, and risky changes governed by an explicit readiness checklist.

## Why Trunk-Based

Long-lived branches are the silent enemy of CI/CD. They:

- Hide integration risk until the merge.
- Encourage giant PRs that are reviewed shallowly.
- Make rollback hard because changes pile up.

Trunk-based development inverts this: branches live hours or a day or two, and CI keeps trunk releasable at all times.

## Operating Rules

- Target branch lifetime: < 24h, hard stop at 3 days. If a feature is not done, hide it behind a flag.
- Pull from trunk daily; small merge conflicts fix themselves.
- All work merges via PR with required checks. Direct push to trunk is forbidden, including for hotfixes.
- Hotfix path: branch off trunk, fix, run gates, merge, deploy. Do not branch off the previous release tag unless you must support an immutable release line.

## Required CI Gates

Before merge, on every PR:

- Build, lint, format, type check.
- Unit + integration tests for changed modules.
- Architecture fitness functions.
- Static security: SAST, secret scan, dependency audit, license check.
- Coverage on changed lines (e.g., ≥ 80%).
- For risky areas (auth, money, schema, data migration): contract tests, smoke tests, replay tests.

Missing or skipped gates require an explicit suppression with owner and reason in the PR description.

## Release Pipeline

- Continuous delivery to staging on every merge.
- Production deploy is a deliberate action: scheduled, button-click, or auto-promoted after canary metrics pass.
- Use progressive delivery: canary, blue-green, or staged rollout. Canary is the default for user-impacting changes.
- Each release records: change list, owner, dashboards, rollback procedure, feature flag state.

## Feature Flags

- New behavior ships behind a flag, default OFF in production.
- Each flag has owner, expiry date, and removal task.
- Stale flags older than the agreed window are flagged in tech debt review.
- Document kill-switch flags in the on-call runbook.

## Release Readiness

For changes touching schema, money, auth, public API, infra, privacy, or AI behavior, fill the Release Readiness Checklist and attach it to the PR / release ticket.

- DB migrations: expand → migrate → contract. Never drop a column in the same release that adds it.
- Backwards-incompatible API / event changes: deprecation window, sunset header, comms.
- Rollback plan exists, is reviewed, and (where feasible) rehearsed.

## Observability At Release

- Define metrics that detect a bad release within 15 minutes (latency, error rate, business KPI).
- Compare canary vs control on those metrics before full rollout.
- Auto-rollback when budgets are breached, or have a one-click manual rollback with documented steps.

## Common Anti-Patterns

- Branching off `develop` and accumulating weeks of work.
- "Release week" or batched monthly releases that paper over CI weakness.
- Feature flags with no owner or expiry, accumulating into a maze.
- Hidden manual steps in production deploy that are not in code or scripts.
- Treating canary metrics as informational; if you do not act on them, you do not have a canary.

## How To Adopt If You Are Not There Yet

1. Fix the slow CI first. Trunk-based is painful with a 30-minute build.
2. Add required PR checks and forbid direct push to main.
3. Introduce feature flags for in-flight work; kill long branches.
4. Add a deploy pipeline to staging on every merge.
5. Add canary + auto-rollback to production for top services.
6. Add the Release Readiness Checklist for risky changes.

## References

- Paul Hammant, "Trunk Based Development".
- Jez Humble, David Farley, "Continuous Delivery".
- Google SRE workbook, "Canarying Releases".
- Martin Fowler, "Feature Toggles", https://martinfowler.com/articles/feature-toggles.html .
