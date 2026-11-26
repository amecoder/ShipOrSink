# RDBMS Schema Change Checklist

Use this for production schema changes in PostgreSQL, MySQL, or another relational database.

## Change Summary

- Change:
- Owner:
- Related PRD / Feature Spec / ADR:
- Migration files:

## Compatibility

- [ ] Migration is forward-compatible with the currently deployed application.
- [ ] Expand/contract plan is defined for breaking changes.
- [ ] Old and new application versions can run during rollout.
- [ ] Rollback or forward-fix path is documented.

## Safety

- [ ] Large table impact is estimated.
- [ ] Lock behavior is understood.
- [ ] Backfill is idempotent, resumable, throttled, and observable.
- [ ] Index creation strategy is safe for production traffic.
- [ ] Query plans were checked for critical paths.

## Data Integrity

- [ ] Primary keys, foreign keys, unique constraints, or checks are updated when needed.
- [ ] Nullability changes are staged safely.
- [ ] Data validation queries are prepared.
- [ ] Backup/restore expectations are clear.

## Operations

- [ ] Metrics and alerts cover migration progress, errors, lock waits, replication lag, and latency.
- [ ] Runbook is linked.
- [ ] On-call owner knows the rollout window.
- [ ] Post-deploy verification queries are listed.
