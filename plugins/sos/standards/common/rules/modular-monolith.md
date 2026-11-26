---
paths:
  - "**/modules/**"
  - "**/packages/**"
  - "**/apps/**"
  - "**/internal/**"
---

# Modular Monolith Rules

Use these rules when the system is deployed as a single unit but must be designed so that future extraction into services is cheap and safe.

## Module Definition

- Each module owns a bounded context: a clear domain capability with its own ubiquitous language.
- Each module has: public API package, domain core, persistence, integration adapters, tests.
- Modules expose only an explicit public API (commands, queries, events, DTOs). Internal packages are not importable from other modules.
- Cross-module communication uses the published API or domain events. Direct DB access across modules is forbidden.

## Data Ownership

- Each module owns its tables/collections/topics. No shared writeable tables between modules.
- Read-only views, materialized projections, or replicated tables across modules require an ADR.
- Foreign keys do not cross module boundaries; reference by ID, validated through the owner module.
- Migrations are scoped per module and live with module code.

## Communication

- Synchronous: call the owner module's public API (function, mediator, in-process bus). No hidden coupling through static singletons.
- Asynchronous: publish domain events with versioned payloads via an in-process or out-of-process bus, ready to swap to Kafka/SQS.
- All inter-module calls must be testable with a fake or contract test of the public API.

## Build And Deploy

- Build graph reflects the module graph; circular dependencies fail the build.
- Each module has its own test target and can be tested in isolation.
- Modules can be promoted to a separate process or service without changing call sites that use the public API.
- Logging, tracing, and metrics carry the module name.

## Review Checklist

- New code for a feature lives in exactly one module.
- No module imports another module's `internal` / `impl` packages.
- New cross-module dependencies are explicitly listed in the module's API doc.
- A module split (modular monolith → service) requires only network adapters, not domain rewrites.
- Fitness functions enforce module boundaries (see architecture-fitness rule).
