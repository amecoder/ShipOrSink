---
paths:
  - "**/domain/**"
  - "**/aggregates/**"
  - "**/entities/**"
  - "**/value_objects/**"
  - "**/valueobjects/**"
  - "**/model/**"
  - "**/models/**"
  - "**/commands/**"
  - "**/events/**"
  - "docs/domain/**"
---

# Domain-Driven Design Rules

Use DDD when the product has meaningful business rules, workflows, or terminology that must remain stable across UI, API, and persistence changes.

## When To Use

- Use DDD for core domains, pricing, billing, permissions, workflow state, matching, scheduling, compliance, or user-facing decision logic.
- Do not force DDD onto CRUD-only admin surfaces, prototypes, or simple integration glue.
- Identify the core domain, supporting domains, and generic subdomains before introducing service boundaries.
- Record bounded-context decisions in an ADR or domain model checklist when a boundary affects teams, databases, APIs, or events.

## Model Rules

- Keep domain language explicit in names: aggregate, entity, value object, policy, command, event, and repository names must match product vocabulary.
- Model invariants inside aggregates or domain services, not in controllers, UI components, database triggers, or ad hoc utility functions.
- Prefer immutable value objects for concepts with equality by value.
- Do not expose persistence models as domain models when they carry ORM, transport, or storage concerns.
- Avoid anemic domain models for core behavior. If business rules live in application services only, document why.

## Aggregate Rules

- One transaction should update one aggregate whenever practical.
- Aggregate roots own invariant enforcement and child entity lifecycle.
- References across aggregates should use identifiers, not object graphs.
- Keep aggregate boundaries small enough to avoid hot rows, lock contention, and large transactional writes.
- Publish domain events after state changes when other bounded contexts need to react.

## Layer Interaction

- Application services orchestrate use cases and transactions; they do not contain domain rules that belong in the model.
- Repositories are ports from the domain/application layer; infrastructure implements them.
- Controllers, resolvers, jobs, and consumers must translate external input into commands or application service calls.
- DTOs and API schemas may not leak into the domain layer.

## Review Checklist

- The bounded context and owner are named.
- Core invariants are represented in domain code and covered by tests.
- Public terms match the product language used by stakeholders.
- Cross-context communication uses APIs or events, not shared database writes.
- The model has a migration path from the current implementation.
