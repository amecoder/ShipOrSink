# Release Readiness Checklist

Use this checklist for any change touching schema, money, auth, public API, infrastructure, data privacy, or AI behavior. Attach the filled-out checklist to the PR / release ticket.

## Release

- Title / version:
- Owner:
- Date / window:
- Linked PR(s):
- Linked PRD / Feature Spec / ADR:

## Scope And Risk

- [ ] Change scope is described (what is changing, what is not).
- [ ] Blast radius classified: low / medium / high / regulated.
- [ ] Affected user segments / tenants / regions listed.

## Tests And Quality Gates

- [ ] CI green: lint, type, unit, integration, contract, security scans.
- [ ] Architecture fitness functions pass.
- [ ] Coverage threshold met on changed lines.
- [ ] Smoke tests cover the critical path of this change.
- [ ] Load / soak test executed for performance-sensitive paths.

## Data And Schema

- [ ] DB migration is backwards compatible (expand → migrate → contract).
- [ ] Migration has a tested rollback or a forward-fix plan.
- [ ] Backfill / data correction job is tested in staging with a representative sample.
- [ ] PII / regulated data flow reviewed against privacy and compliance rules.

## API And Contracts

- [ ] Public API / event schema changes are versioned and documented.
- [ ] Breaking changes follow the deprecation policy (sunset header, timeline, comms).
- [ ] OpenAPI / AsyncAPI / Proto contracts updated.
- [ ] Consumer-driven contract tests pass.

## Feature Flags

- [ ] New behavior is gated behind a flag with default OFF.
- [ ] Flag has owner, expiry, and ramp plan.
- [ ] Kill-switch path is documented in the runbook.

## Rollout Plan

- [ ] Strategy: canary / blue-green / staged rollout / dark launch.
- [ ] Canary cohort and ramp schedule defined.
- [ ] Auto-rollback criteria (metric thresholds) defined.
- [ ] Manual rollback steps documented and rehearsed.

## Observability

- [ ] Logs, metrics, traces, and dashboards updated for the new behavior.
- [ ] Alerts / SLOs reviewed; new alerts paged-on or paged-off as needed.
- [ ] On-call team notified; on-call runbook updated.

## Security And Compliance

- [ ] Secrets and access scopes reviewed (least privilege).
- [ ] Audit logging captures security-relevant events introduced by this change.
- [ ] Compliance / privacy review completed where applicable.
- [ ] Vendor / sub-processor changes documented.

## Communications

- [ ] Customer-facing communication / changelog drafted (if applicable).
- [ ] Internal stakeholders (support, sales, ops) informed.
- [ ] Status page entry prepared for high-risk releases.

## Sign-Off

- Engineering owner:
- SRE / on-call:
- Product owner:
- Security / compliance (if regulated):
- Approval date:

## Post-Release

- [ ] First-N-minutes monitoring complete; metrics within budget.
- [ ] Canary promoted / rolled back with reason logged.
- [ ] Stale flags / migrations cleaned up follow-up issue created.
