# Domain Model Checklist

Use this checklist before implementing or changing core business logic.

## Context

- Domain:
- Bounded context:
- Owner:
- Stakeholders:
- Related ADR or design doc:

## Ubiquitous Language

| Term | Meaning | Source |
|------|---------|--------|
| | | |

## Model

- [ ] Core aggregate roots are named.
- [ ] Entities and value objects are separated.
- [ ] Invariants are listed and owned by aggregate/domain code.
- [ ] Cross-aggregate references use identifiers.
- [ ] Domain events are named when other contexts need to react.

## Invariants

| Invariant | Enforced By | Test |
|-----------|-------------|------|
| | | |

## Boundaries

- [ ] API DTOs do not leak into the domain model.
- [ ] ORM/persistence models do not define domain behavior.
- [ ] Repositories are ports or interfaces.
- [ ] External dependencies are behind adapters.

## Test Plan

- Unit:
- Integration:
- Contract:
- Migration/regression:

## Decision

- Approved by:
- Date:
- Follow-up:
