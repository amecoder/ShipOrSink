---
paths:
  - "**/repositories/**"
  - "**/persistence/**"
  - "**/infra/**"
  - "**/*mongo*"
  - "**/*dynamo*"
  - "**/*cassandra*"
  - "**/*redis*"
  - "**/*elastic*"
---

# NoSQL Rules

NoSQL databases are specialized storage engines. Use them for a clear access pattern or scaling model, not to avoid schema design.

## Decision Gate

- Write a Database Decision Record before introducing MongoDB, DynamoDB, Cassandra, Elasticsearch/OpenSearch, Redis as a primary store, graph databases, vector databases, or time-series databases.
- Prove why the existing RDBMS plus indexing, JSONB, read replicas, partitioning, caching, or search projection is insufficient.
- Define whether the NoSQL store is the source of truth or a derived projection.

## Access Pattern First

- Model data from known read/write access patterns, cardinality, item size, hot keys, and retention needs.
- Define partition keys, sort keys, shard keys, or routing keys before implementation.
- Validate worst-case fan-out, pagination, consistency, and query limits.
- Avoid cross-partition scans, unbounded filters, and query patterns that require full collection/table scans.

## Consistency And Ownership

- State the consistency model: strong, bounded stale, eventual, or best-effort cache.
- Derived stores must be rebuildable from the source of truth or append-only event stream.
- Dual writes are forbidden unless protected by outbox, CDC, idempotency, reconciliation, and alerting.
- Consumers must tolerate duplicate, delayed, or out-of-order projection updates.

## Operations

- Define backup, restore, export, TTL, compaction, index rebuild, and disaster recovery procedures.
- Monitor p50/p95/p99 latency, throttling, hot partitions, replication lag, storage growth, index size, and error rate.
- Capacity and cost modeling must include read/write units, index amplification, retention, and cross-region traffic.

## Security

- Validate user-controlled query objects to prevent NoSQL injection.
- Apply least-privilege access per collection/table/index.
- Classify PII and define field-level encryption or tokenization when required.

## Forbidden

- Using NoSQL because "schema-less" sounds faster.
- Storing relational transactional data in NoSQL without explicit consistency tradeoffs.
- Treating Redis/cache as durable source of truth without persistence, recovery, and incident plans.
- Adding search/vector/graph stores without rebuild and synchronization strategy.
