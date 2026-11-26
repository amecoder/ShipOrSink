# NoSQL Adoption Checklist

## Decision Gate

- [ ] Database Decision Record is written.
- [ ] Existing RDBMS, indexing, partitioning, read replicas, JSONB, caching, or search projection were considered.
- [ ] Source of truth vs derived projection is explicit.
- [ ] Consistency model is documented.
- [ ] Rebuild strategy exists for derived data.

## Data Model

- [ ] Access patterns are listed before schema/model design.
- [ ] Partition/shard/routing keys are defined.
- [ ] Hot key and high-cardinality risks are tested.
- [ ] Item/document size limits are checked.
- [ ] Pagination and query limits are tested.
- [ ] Secondary indexes are justified by named query patterns.

## Write Path

- [ ] Idempotency strategy exists.
- [ ] Duplicate, delayed, and out-of-order updates are handled.
- [ ] Dual writes are avoided or protected by outbox/CDC/reconciliation.
- [ ] Retry behavior is safe.

## Operations

- [ ] Backup and restore are tested.
- [ ] TTL, retention, and deletion behavior are documented.
- [ ] Metrics exist for latency, throttling, hot partitions, storage, replication, and errors.
- [ ] Cost model includes read/write units, storage, indexes, and cross-region traffic.
- [ ] Runbook and incident owner are assigned.

## Security

- [ ] User-controlled query objects are validated.
- [ ] Least-privilege access is configured.
- [ ] PII fields are classified.
- [ ] Encryption/tokenization is applied where required.
