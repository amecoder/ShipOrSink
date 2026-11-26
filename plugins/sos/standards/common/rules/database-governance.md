---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/migrate/**"
  - "**/db/**"
  - "**/database/**"
  - "**/repositories/**"
  - "**/persistence/**"
  - "**/models/**"
  - "**/entities/**"
  - "**/schema*"
  - "**/prisma/**"
  - "**/alembic/**"
  - "docs/database/**"
---

# Database Governance Rules

Database choices are architecture decisions, not implementation details.

## Default Position

- Use the existing primary database unless a measured constraint proves it is insufficient.
- Prefer PostgreSQL or the existing relational store for MVP and early product work.
- Treat Redis, search indexes, analytics stores, vector stores, and caches as derived stores unless an ADR explicitly makes them a source of truth.
- Do not introduce a new database technology without a Database Decision Record.

## Required Decision Record

Write a database decision record before adding or replacing any of the following:

- Primary OLTP database
- Distributed SQL or NewSQL system such as TiDB, CockroachDB, or YugabyteDB
- Event store, warehouse, search engine, vector database, graph database, or time-series database
- Cross-region replication, CDC, sharding, or multi-writer topology

The decision record must cover:

- Problem statement and measured constraint
- Alternatives considered, including keeping the current database
- Source-of-truth ownership and derived-store synchronization
- Transaction isolation and consistency expectations
- Migration, rollback, backup, restore, and disaster recovery plan
- Local development, CI, staging, and production parity
- Observability, on-call ownership, operational runbooks, and cost model

## Source Of Truth

- A business entity must have one authoritative store.
- Derived stores must be rebuilt from the source of truth or an append-only event stream.
- Application code must not write the same business fact independently to multiple databases.
- Cross-store consistency must be explicit: strong consistency, bounded staleness, or eventual consistency.

## Migration And Operations

- Schema migrations must be forward-only after deployment.
- Data migrations must be idempotent, observable, and resumable.
- Backup restore must be tested before production cutover.
- Rollback must name the exact fallback path: revert code, forward-fix data, dual-write drain, or restore.
- Every new database requires dashboards for latency, error rate, saturation, storage, replication, and backup status.

## Forbidden

- Adding a database because it is trendy.
- Adding a database to avoid modeling ownership or query boundaries.
- Using a distributed database to compensate for unbounded queries or missing indexes.
- Treating MySQL compatibility, PostgreSQL compatibility, or SQL support as proof of drop-in replacement.
- Introducing a managed database without export, backup, cost, and incident-response plans.
