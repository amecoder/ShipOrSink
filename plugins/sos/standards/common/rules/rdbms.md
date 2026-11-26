---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/repositories/**"
  - "**/persistence/**"
  - "**/infra/**"
---

# RDBMS Rules

Relational databases are the default choice for transactional product data unless a documented requirement proves otherwise.

## When To Use

- Use PostgreSQL or the existing RDBMS for MVPs, billing, permissions, workflow state, audit trails, and strongly consistent business records.
- Prefer relational modeling when relationships, constraints, reporting, and transaction boundaries matter.
- Use JSON/JSONB tactically for extension fields, not as a substitute for an unmodeled domain.

## Schema Design

- Every table must have a primary key, ownership, retention policy, and migration path.
- Model required business invariants with constraints when the database can enforce them reliably.
- Foreign keys are preferred for core transactional data unless there is a documented scale or deployment reason to avoid them.
- Indexes must be tied to observed or expected query patterns; do not add speculative indexes.
- Large tables require an explicit partitioning, archival, or pruning strategy before they become operational risks.

## Transactions And Isolation

- Define the transaction boundary in the application service or use case layer.
- Avoid long-running transactions around network calls, message publishing, file I/O, or user interaction.
- Choose isolation level deliberately when money, inventory, permissions, or workflow state can race.
- Use optimistic locking, idempotency keys, or unique constraints for retry-safe writes.

## Migrations

- Migrations must be forward-compatible with the currently deployed application version.
- Expand and contract: add nullable/new structures first, dual-read or dual-write when needed, then remove old fields later.
- Backfills must be idempotent, resumable, throttled, and observable.
- Rollback must be explicit: revert code, run a forward-fix migration, restore backup, or switch traffic.

## Operations

- Monitor query latency, lock waits, deadlocks, connection pool saturation, replication lag, storage, and backup status.
- Test backup restore before production cutover and on a recurring schedule.
- Capacity planning must include write amplification from indexes, CDC, triggers, and audit tables.

## Forbidden

- Treating ORM models as the source of truth for schema design.
- Running destructive DDL in application startup code.
- Adding indexes without query evidence or a named access pattern.
- Sharing one database schema across bounded contexts without ownership boundaries.
