# Database Decision Record

> Use this template before adding, replacing, or materially changing a database.
> Store completed records under `docs/adr/` or `docs/database/`.

## Status

Proposed | Accepted | Rejected | Superseded

## Date

YYYY-MM-DD

## Participants

-

## Decision Summary

We will use:

- Database:
- Role: source of truth | derived store | cache | analytics | search | vector | event store
- Scope:
- Owner:

## Problem

- What product or operational constraint requires this decision?
- What measured evidence shows the current storage approach is insufficient?
- What happens if we do nothing?

## Requirements

| Requirement | Target |
|-------------|--------|
| Data volume | |
| Write throughput | |
| Read throughput | |
| p95/p99 latency | |
| Availability | |
| Recovery point objective | |
| Recovery time objective | |
| Consistency model | strong \| bounded staleness \| eventual |
| Retention | |
| Compliance/privacy | |

## Alternatives

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Keep current DB | | | |
| PostgreSQL/MySQL | | | |
| Distributed SQL/NewSQL | | | |
| Search/analytics/vector/other | | | |

## Source Of Truth

- Authoritative entity or aggregate:
- Tables/collections/topics owned:
- Derived stores:
- Rebuild path for derived stores:
- Cross-store consistency model:

## Application Impact

- API changes:
- Query changes:
- ORM/driver compatibility:
- Migration tooling:
- Local development setup:
- CI/staging/prod parity:

## Migration Plan

1.

## Rollback Or Forward-Fix Plan

- Code rollback:
- Data rollback or forward-fix:
- Dual-write drain:
- Restore path:

## Operations

- Dashboards:
- Alerts:
- Backup schedule:
- Restore test date:
- Runbooks:
- On-call owner:
- Cost estimate:

## Security And Privacy

- Access model:
- Secrets management:
- Encryption:
- Audit logging:
- Data deletion:

## Decision

We choose:

Rationale:

## Consequences

### Positive

-

### Negative

-

### Follow-Up

-
