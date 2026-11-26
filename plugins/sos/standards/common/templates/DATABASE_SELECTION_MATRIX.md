# Database Selection Matrix

Use this before introducing or replacing a database.

## Context

- Feature / system:
- Owner:
- Date:
- Related PRD / Feature Spec / ADR:

## Requirement Summary

| Requirement | Detail | Hard requirement? |
|-------------|--------|-------------------|
| Data ownership | | Yes / No |
| Transaction consistency | | Yes / No |
| Query patterns | | Yes / No |
| Write throughput | | Yes / No |
| Read throughput | | Yes / No |
| Latency target | | Yes / No |
| Data volume / growth | | Yes / No |
| Retention / deletion | | Yes / No |
| Region / availability | | Yes / No |
| Compliance / PII | | Yes / No |

## Options

| Option | Fit | Risks | Operations | Cost | Decision |
|--------|-----|-------|------------|------|----------|
| Existing RDBMS | | | | | |
| PostgreSQL / MySQL | | | | | |
| Distributed SQL / NewSQL | | | | | |
| Document DB | | | | | |
| Key-value / cache | | | | | |
| Search engine | | | | | |
| Vector DB | | | | | |
| Graph DB | | | | | |
| Time-series DB | | | | | |

## Source Of Truth

- Authoritative store:
- Derived stores:
- Rebuild mechanism:
- Consistency model:
- Reconciliation process:

## Access Patterns

| Pattern | Frequency | Expected p95 | Data shape | Index / key strategy |
|---------|-----------|--------------|------------|----------------------|
| | | | | |

## Migration Plan

- Initial rollout:
- Backfill:
- Dual-read / dual-write plan:
- Cutover:
- Rollback:

## Operations

- Backup / restore:
- Monitoring:
- Alerts:
- Runbook:
- On-call owner:

## Decision

- Selected database:
- Why:
- Rejected alternatives:
- Review date:
