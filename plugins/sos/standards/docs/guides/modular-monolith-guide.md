# Modular Monolith Guide

## Goal

Get most of the benefits of clear service boundaries (independent reasoning, isolated data, replaceable internals) without paying the operational cost of microservices on day one. Keep the option of extracting any module into a separate service later, cheaply.

## When To Choose A Modular Monolith

- The team is small to medium and operational overhead of N services would slow product work.
- The bounded contexts are not yet stable enough to commit to network boundaries.
- Latency and consistency between modules favor in-process calls.
- A single deploy unit is acceptable for the foreseeable future.

When you need independent scaling, independent release cadence, language diversity, or strong fault isolation, microservices are the right answer. Use the microservice-architecture guide instead.

## Module Anatomy

Each module is a slice of the system aligned with a bounded context.

```
modules/
  billing/
    api/         public commands, queries, events, DTOs
    domain/      entities, value objects, policies, ports
    application/ use cases, transactions
    infra/       repositories, external clients
    internal/    private helpers, wiring
    tests/
```

- `api` is the only package other modules import.
- `internal` is invisible to other modules; enforced by build / dependency tools.
- `domain` follows the layered or hexagonal pattern.

## Data Ownership Rules

- Each module owns its tables / collections / topics.
- No cross-module joins. To get data owned by another module, call its query.
- No foreign keys to tables in other modules. Use IDs validated by the owner module.
- Migrations live with module code. Order is enforced by tooling, not by hope.

## Communication

- In-process call to public API for synchronous needs.
- Domain events for asynchronous flows. Even in-process, use a versioned event with a publisher and subscribers, ready to swap to Kafka / SQS without touching call sites.
- Forbid hidden coupling: shared singletons, ambient context, static caches.

## Build And Deploy

- Build graph reflects module graph.
- Each module is its own test target; can be tested in isolation.
- One deployable artifact today, but extraction to a separate service should require only network adapters around the public API.

## Fitness Functions To Add Early

- "No module imports another module's `internal` package."
- "Module dependency graph has no cycles."
- "All cross-module calls go through `api` packages."
- For each module, "tests in this module pass without touching another module's DB."

## Extraction Path

When a module's needs justify extraction:

1. Replace its public API calls with HTTP / gRPC adapters that match the same contract.
2. Move its tables to a dedicated database; keep events as the integration spine.
3. Promote in-process domain events to a real broker.
4. Keep the rest of the modular monolith unchanged.

If the public API was clean, this is a few weeks of work, not a quarter.

## Common Mistakes

- "Shared kernel" packages that everyone imports. They become a dumping ground; split into clear ownership.
- Direct DB access from another module's repository for a "quick read." Always pay the call.
- Treating module boundaries as advisory and skipping fitness functions. Boundaries decay without enforcement.
- Splitting too early on speculative seams. Wait until you have at least one real use case crossing the boundary.

## References

- Simon Brown, "Modular Monoliths".
- Kamil Grzybek, "Modular Monolith with DDD".
- Spring Modulith documentation, https://docs.spring.io/spring-modulith .
- Sam Newman, "Monolith to Microservices".
