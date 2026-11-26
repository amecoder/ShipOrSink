---
paths:
  - "**/domain/**"
  - "**/application/**"
  - "**/ports/**"
  - "**/adapters/**"
  - "**/infrastructure/**"
  - "**/usecases/**"
  - "**/use_cases/**"
---

# Hexagonal / Clean Architecture Rules

Apply these rules whenever a service or module is expected to outlive its current framework, persistence, or transport choice.

## Core Principles

- Domain core (entities, value objects, use cases, policies) must not import frameworks, ORM types, HTTP libraries, queue clients, file systems, clocks, or random sources.
- Define ports (interfaces) for everything the domain needs from the outside: persistence, messaging, time, identity, payments, search, AI providers.
- Adapters live at the edge and implement ports. Replace adapters without rewriting the domain.
- Dependencies flow inward only. Outer layers know inner layers; inner layers do not know outer layers.

## Boundary Layout

- `domain/`: entities, value objects, aggregates, policies, domain services, domain events, port interfaces.
- `application/` (or `usecases/`): orchestrates domain via ports, transactions, authorization, idempotency.
- `adapters/`:
  - `inbound/` (driving): HTTP controllers, GraphQL resolvers, queue consumers, CLI, schedulers.
  - `outbound/` (driven): repositories, message publishers, third-party clients, mailers.
- `bootstrap/` or `composition/`: wires concrete adapters to ports at startup.

## Hard Rules

- Domain must compile and run unit tests without containers, network, framework startup, or DB.
- No annotations from web/ORM/queue frameworks on domain types.
- No SQL strings, HTTP routes, or queue topic names inside domain or application.
- Cross-aggregate side effects go through ports, not direct calls.
- Errors crossing inbound boundaries are translated to transport-appropriate responses; domain raises typed errors only.

## Testing

- Unit tests cover domain and use cases with in-memory port fakes.
- Adapter tests verify each adapter against contract or integration tests.
- End-to-end tests assemble the full hexagon to validate wiring and observability.
- Replacing an adapter (e.g., DB engine, AI provider) must not require domain test changes.

## Review Checklist

- Inbound traffic enters via an adapter that calls a use case.
- Use cases invoke domain logic through ports.
- Outbound effects exit through ports implemented by adapters.
- No cyclic imports between layers.
- Each port has at least one adapter and one fake for tests.
