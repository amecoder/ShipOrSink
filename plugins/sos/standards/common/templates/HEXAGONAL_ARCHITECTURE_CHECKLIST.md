# Hexagonal / Clean Architecture Checklist

Use this checklist for any new bounded context, large refactor, or AI-generated module that is expected to outlive its current framework or persistence choice.

## Module

- Module / bounded context:
- Owner:
- Related PRD / Feature Spec / ADR:

## Domain Core

- [ ] Domain has no framework, ORM, HTTP, queue, file system, clock, or random imports.
- [ ] All external effects are expressed as ports (interfaces) defined inside the domain or application layer.
- [ ] Domain entities and value objects are immutable where the language supports it.
- [ ] Domain errors are typed and meaningful; no generic exceptions leaking out.

## Application / Use Cases

- [ ] Each use case has a single entry point and explicit input/output types.
- [ ] Authorization, transaction, and idempotency rules are in the use case, not in adapters.
- [ ] Cross-aggregate effects go through ports.

## Inbound Adapters (driving)

- [ ] HTTP / GraphQL / queue / CLI adapters call use cases only — no domain logic in controllers.
- [ ] DTOs at the inbound boundary are separate from domain types.
- [ ] Errors are translated into transport-appropriate responses.

## Outbound Adapters (driven)

- [ ] Each port has at least one production adapter and one fake/in-memory implementation for tests.
- [ ] Adapter classes contain no business rules.
- [ ] External calls have timeout, retry, and fallback policy aligned with the use case.

## Composition Root

- [ ] Wiring of concrete adapters to ports is in a single composition root, not scattered.
- [ ] Configuration (DB URL, provider keys, flags) is injected, not read from globals inside domain code.

## Tests

- [ ] Domain unit tests run with no DB, no HTTP, no framework startup.
- [ ] Use case tests cover happy path, authorization, error mapping, and idempotency.
- [ ] Adapter tests verify against real or contract-test doubles.
- [ ] Replacing the persistence engine, queue, or AI provider would not require changes to domain tests.

## Fitness Functions

- [ ] An automated check enforces "no framework imports in domain".
- [ ] Cyclic dependencies between layers fail the build.
- [ ] PR template links to this checklist for changes affecting boundaries.

## Exceptions

List any intentional violation, the owner, and the planned resolution date:

-
