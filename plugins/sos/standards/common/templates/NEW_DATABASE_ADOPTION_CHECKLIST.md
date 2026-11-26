# New Database Adoption Checklist

Use this checklist before introducing a new database technology into a product repository.

## Decision Gate

- [ ] A Database Decision Record exists.
- [ ] Keeping the existing database was evaluated.
- [ ] The new database has a named source-of-truth or derived-store role.
- [ ] The decision is tied to measured constraints, not preference.
- [ ] The team has an owner for operations and incident response.

## Compatibility

- [ ] Driver, ORM, migration tool, and query builder are verified.
- [ ] Local development setup is documented.
- [ ] CI can run representative integration tests.
- [ ] Staging environment matches production-relevant topology.
- [ ] Unsupported SQL or API features are listed.

## Data And Migration

- [ ] Schema design is reviewed.
- [ ] Indexes and query plans are reviewed.
- [ ] Backfill is idempotent and resumable.
- [ ] Rollback or forward-fix path is documented.
- [ ] Backup and restore were tested.
- [ ] Data retention and deletion requirements are satisfied.

## Operations

- [ ] Dashboards exist for latency, errors, saturation, storage, and replication.
- [ ] Alerts are tied to user impact and recovery actions.
- [ ] Runbook exists for connection storms, slow queries, storage pressure, and failover.
- [ ] Upgrade procedure is documented.
- [ ] Cost model and scaling limits are documented.

## Security

- [ ] Least-privilege users are configured.
- [ ] Secrets are stored in the approved secret manager.
- [ ] Encryption in transit and at rest is enabled.
- [ ] Audit logging covers sensitive data access.
- [ ] PII deletion and export flows were tested.

## Approval

- Product owner:
- Engineering owner:
- Infrastructure/SRE owner:
- Security reviewer:
