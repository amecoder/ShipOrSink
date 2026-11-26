---
paths:
  - "**/commands/**"
  - "**/queries/**"
  - "**/projections/**"
  - "**/event_store/**"
  - "**/eventstore/**"
  - "**/read_model*/**"
  - "**/readmodel*/**"
  - "**/*Projection*"
  - "**/*EventStore*"
  - "docs/architecture/**"
---

# CQRS / Event Sourcing Decision Rules

CQRS and event sourcing solve specific problems and add real cost. Adopt only when the criteria below are met. The default is CRUD with a relational database.

## When CQRS May Apply

- Read and write workloads have very different shapes (e.g., heavy fan-out reads vs low-volume writes) and a single model is causing query or write contention.
- The team needs different consistency or scaling characteristics on the read side (e.g., search, analytics, projections) that the write store cannot serve well.
- Authorization or audit on writes differs significantly from reads.
- A simple read model derived from the write model is worth the operational cost of two stores.

## When Event Sourcing May Apply

- Auditability of every state change is a hard requirement (finance, healthcare, regulated workflows).
- Time-travel, replay, or reprocessing into new read models is a recurring need.
- Domain logic is best expressed as a sequence of meaningful events, not snapshots.
- The team has the discipline to manage event versioning, snapshots, projections, and replay infrastructure.

## When NOT To Adopt

- Simpler patterns (read replicas, materialized views, caching, search index) solve the problem.
- The team has not yet stabilized the domain model and ubiquitous language.
- There is no operational plan for event replay, schema evolution, projection rebuilds, or DLQ handling.
- The driver is novelty, "scalability someday", or résumé-driven design.

## Required Artifacts Before Adoption

- A `CQRS_DECISION_RECORD.md` (see template) covering: problem, alternatives considered, expected reads/writes, consistency model, command/event/query model, projection rebuild strategy, rollback plan.
- An ADR linked from the decision record.
- An eventual consistency budget (acceptable lag) agreed with product/ops.
- A fitness function ensuring commands do not query the read model and queries do not mutate state.
- A runbook for replay, projection rebuild, and event schema upgrades.

## Operational Rules When Adopted

- Events are versioned; renaming or removing a field requires an upcaster or new event type.
- Projections are idempotent and replayable.
- Outbox pattern (or equivalent) for any cross-store write.
- Snapshots policy defined for long-lived aggregates.
- Observability: command latency, event lag, projection rebuild time, DLQ depth.

## Review Checklist

- Decision record exists and links to ADR.
- Read model and write model are clearly separated, with documented eventual consistency window.
- Replay/rebuild scripts are tested in staging.
- Schema evolution path documented for each event type.
- Team has runbook ownership for projection failures and DLQs.
