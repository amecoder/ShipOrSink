# Distributed SQL Readiness Checklist

Use this checklist for TiDB, CockroachDB, YugabyteDB, or another distributed SQL/NewSQL database.

## Use Case Fit

- [ ] Horizontal write scale, high availability, regional placement, or HTAP is a real requirement.
- [ ] A single-node or managed conventional RDBMS cannot meet the requirement with indexing, partitioning, read replicas, or caching.
- [ ] The product can tolerate the database-specific consistency and latency tradeoffs.
- [ ] The team understands that SQL compatibility is not drop-in equivalence.

## Modeling And Query Design

- [ ] Primary keys avoid write hotspots.
- [ ] High-write tables were tested with production-like concurrency.
- [ ] Cross-aggregate transactions are minimized.
- [ ] Query plans were reviewed on realistic data volume.
- [ ] p95 and p99 latency were measured under load.
- [ ] Long-running analytical queries are isolated or routed to an analytical path.

## TiDB-Specific Checks

- [ ] MySQL compatibility limitations are reviewed.
- [ ] DDL behavior is tested.
- [ ] View, collation, SQL mode, built-in function, and optimizer hint differences are reviewed.
- [ ] Pessimistic lock behavior is tested when used.
- [ ] TiKV, PD, and TiDB Server metrics are visible.
- [ ] TiFlash is used only when table-level analytical replicas are justified.
- [ ] Backup/restore, migration, and TiCDC or replication tooling are tested.

## Resilience

- [ ] Node failure was tested.
- [ ] Network partition or high-latency behavior was tested where practical.
- [ ] Failover target and recovery procedure are documented.
- [ ] Region or replica placement rules are documented.
- [ ] Upgrade and rollback order is documented.

## Operations

- [ ] Dashboard includes cluster health, region distribution, transaction conflicts, slow queries, replication, storage, and backup status.
- [ ] Alerts map to runbook actions.
- [ ] Capacity plan covers storage, compute, and network.
- [ ] Managed service limits and maintenance windows are documented.
