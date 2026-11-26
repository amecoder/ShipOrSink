# CQRS / Event Sourcing Decision Record

Use this record before adopting CQRS, event sourcing, or both. The default answer is "do not adopt" unless this record is filled out, reviewed, and linked from an ADR.

## Metadata

- Title:
- Date:
- Status: proposed / accepted / rejected / superseded
- Decision owner:
- Reviewers:
- Related ADRs / Design Docs / PRD:

## Problem

What problem are we solving? Be specific (latency, contention, audit, replay, scaling, query shape, regulatory).

-
-

## Current State

- Read workload (RPS, p95, query shape, growth):
- Write workload (RPS, p95, transaction boundaries):
- Bottleneck observed (cite metrics, traces, or incidents):
- Already tried (read replica, materialized view, search index, caching, sharding, denormalization):

## Proposed Pattern

- [ ] CQRS only (separate read model)
- [ ] Event sourcing only (event log as source of truth, read model derived)
- [ ] CQRS + event sourcing
- [ ] Other:

## Justification

Why is the proposed pattern the right answer over simpler alternatives? Map to the criteria in `cqrs-event-sourcing.md` rule.

-
-

## Alternatives Considered

| Alternative | Pros | Cons | Reason rejected |
|-------------|------|------|-----------------|
| Read replica + materialized view |  |  |  |
| Search index / OLAP store |  |  |  |
| Caching layer |  |  |  |
| Sharding / partitioning |  |  |  |
| Stay CRUD |  |  |  |

## Model

- Commands:
- Events:
- Queries / read models:
- Aggregates / streams:
- Eventual consistency window (acceptable lag):
- Projection rebuild strategy:
- Snapshot policy (event sourcing only):

## Operational Plan

- Storage choices (write store, event store, read store):
- Outbox or transactional event publishing:
- Idempotency strategy for projections:
- Schema evolution / upcaster strategy for events:
- DLQ + replay tooling:
- Observability: command latency, event lag, projection rebuild time, DLQ depth.
- Runbook owner and link:

## Risks

-
-

## Rollback Plan

How do we get back to a simpler model if this pattern does not pay off?

-
-

## Decision

- Decision:
- Conditions / guardrails:
- Re-evaluation date:
