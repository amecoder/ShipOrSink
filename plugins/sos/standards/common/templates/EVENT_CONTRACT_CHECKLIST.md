# Event Contract Checklist

Use this checklist before producing, changing, or consuming production events.

## Event

- Event name:
- Producer:
- Consumers:
- Topic/stream:
- Schema location:
- Owner:

## Contract

- [ ] Event name is a past-tense domain fact.
- [ ] Event id, source, type, schema version, subject/aggregate id, occurred time, and trace context are present.
- [ ] Payload excludes unnecessary PII and secrets.
- [ ] Compatibility strategy is documented.
- [ ] Example payload is included.

## Delivery

- [ ] Consumer idempotency key is defined.
- [ ] Retry, backoff, and DLQ behavior are defined.
- [ ] Replay behavior is documented.
- [ ] Ordering assumptions are explicit.
- [ ] Outbox or equivalent atomicity strategy is defined when required.

## Operations

- [ ] Retention period:
- [ ] Partitioning key:
- [ ] Alerts:
- [ ] Dashboards:
- [ ] Runbook:

## Rollout

- [ ] Producer deployed before strict consumers when additive.
- [ ] Consumers tolerate unknown fields.
- [ ] Breaking changes have a dual-publish or migration window.
- [ ] Rollback plan exists.
