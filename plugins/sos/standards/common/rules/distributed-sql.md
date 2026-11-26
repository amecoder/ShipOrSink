---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/db/**"
  - "**/database/**"
  - "**/repositories/**"
  - "**/repositories/**/*"
  - "**/persistence/**"
  - "**/persistence/**/*"
  - "**/infra/**"
  - "**/infra/**/*"
---

# Distributed SQL Rules

Distributed SQL and NewSQL systems such as TiDB, CockroachDB, and YugabyteDB are production architecture choices.

## Adoption Gate

- Keep a conventional relational database unless horizontal write scale, regional availability, or HTAP requirements are proven.
- Require a Database Decision Record before adopting distributed SQL.
- Run a proof of concept with the application's real query patterns, migrations, ORM, backups, and failure modes.
- Validate compatibility against official limitations; do not assume MySQL or PostgreSQL compatibility is complete.

## Data Modeling

- Prefer globally unique, non-hotspot identifiers for high-write tables.
- Avoid monotonic hot keys unless the selected database documents safe handling.
- Design primary keys, indexes, and partitioning with data distribution in mind.
- Keep transactions small and bounded by business use case.
- Avoid cross-aggregate transactions unless the consistency requirement is explicit.

## Query And Transaction Rules

- Use explicit transactions for multi-statement writes.
- Treat isolation level behavior as database-specific and document it in repository tests.
- Test pessimistic locking, unique constraints, generated IDs, DDL, and ORM migrations against the target database.
- Do not depend on unsupported engine-specific SQL syntax.
- Benchmark p95 and p99 latency under realistic concurrency, not only average latency.

## TiDB-Specific Rules

- Treat TiDB as MySQL-compatible, not MySQL-identical.
- Verify unsupported or different MySQL behavior for DDL, views, built-in functions, collations, SQL modes, optimizer hints, and locks.
- Remember that TiDB Server is stateless SQL compute; TiKV stores row data; PD schedules metadata and transaction IDs; TiFlash is optional columnar storage.
- Use TiFlash only when HTAP or near-real-time analytical queries justify the extra operational surface.
- Validate online DDL, backup/restore, TiCDC or migration tooling, and TiDB Dashboard metrics before production.

## Operations

- Track leader distribution, region health, replication lag, transaction conflicts, slow queries, storage growth, and backup status.
- Define failover drills for SQL layer, placement driver, and storage nodes.
- Document upgrade order and version compatibility across database components.
- For managed offerings, document limits, maintenance windows, network topology, and export strategy.
