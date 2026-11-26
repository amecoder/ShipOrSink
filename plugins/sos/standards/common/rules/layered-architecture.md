---
paths:
  - "**/controllers/**"
  - "**/handlers/**"
  - "**/services/**"
  - "**/repositories/**"
  - "**/domain/**"
  - "**/application/**"
  - "**/infrastructure/**"
  - "**/presentation/**"
  - "**/usecases/**"
  - "**/use_cases/**"
---

# Layered Architecture Rules

Keep dependency direction explicit so the system remains testable, replaceable, and easy for humans and AI agents to modify.

## Default Layers

- Presentation: HTTP controllers, pages, UI components, CLI commands, message handlers.
- Application: use cases, orchestration, transactions, authorization checks, workflow coordination.
- Domain: entities, value objects, aggregates, policies, domain services, domain events.
- Infrastructure: database, ORM, external clients, queues, storage, framework adapters.

## Dependency Direction

- Presentation may depend on application contracts.
- Application may depend on domain and ports.
- Domain must not depend on presentation, infrastructure, framework annotations, HTTP, SQL, queue clients, or environment variables.
- Infrastructure implements ports defined by application/domain layers.
- Shared utilities must not depend on feature modules.

## Boundaries

- Keep DTOs at boundaries. Do not pass raw request bodies, ORM entities, or provider responses deep into the domain.
- Use mappers at the edge when crossing API, persistence, or event boundaries.
- Define ports for external systems that affect tests, availability, latency, or cost.
- Avoid circular imports. Extract a smaller contract when cycles appear.

## Testing

- Domain tests should run without databases, networks, clocks, or framework bootstrapping.
- Application tests may use fake ports or transaction-bound integration tests.
- Infrastructure tests verify adapters against real or contract-test doubles.
- UI/API tests cover boundary validation and user-visible errors.

## Review Checklist

- Dependencies point inward.
- Domain logic is not hidden in controllers, components, SQL strings, or queue consumers.
- External systems are behind ports.
- Tests can exercise business rules without booting the whole app.
- New abstractions remove real coupling rather than adding ceremony.
