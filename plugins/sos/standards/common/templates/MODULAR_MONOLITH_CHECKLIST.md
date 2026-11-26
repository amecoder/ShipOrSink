# Modular Monolith Module Boundary Checklist

Use this checklist when introducing or significantly changing a module in a modular monolith.

## Module

- Module name:
- Bounded context / capability:
- Owner:
- Related PRD / Feature Spec / ADR:

## Public API

- [ ] Public package(s) listed and stable: `module.api.*`
- [ ] All cross-module callers use the public API only.
- [ ] Internal packages (`internal`, `impl`, `__internal__`) are not importable from outside.
- [ ] DTOs at the boundary are separate from domain types.
- [ ] Domain events published by the module are listed and versioned.

## Data Ownership

- [ ] Tables / collections / topics owned by this module are listed.
- [ ] No other module writes to these tables directly.
- [ ] Foreign keys do not cross module boundaries.
- [ ] Migrations live with module code and run in module-scoped order.
- [ ] Read-only views / projections crossing modules are explicitly documented.

## Communication

- [ ] Synchronous calls go through the public API (function, mediator, in-process bus).
- [ ] Asynchronous flows publish versioned domain events.
- [ ] Each inter-module dependency is unidirectional or justified in an ADR.
- [ ] Static singletons / globals are not used to share state across modules.

## Build And Test

- [ ] Build graph reflects module graph; cycles fail the build.
- [ ] Module has its own test target and can be tested in isolation.
- [ ] Contract tests exist for public API surface (consumer + provider).
- [ ] Logging / tracing / metrics include the module name.

## Future Service Extraction

- [ ] Extracting this module into its own service requires only network adapters, not domain rewrites.
- [ ] Outbound calls to other modules already go through ports.
- [ ] Persistence is encapsulated and replaceable per module.

## Fitness Functions

- [ ] Automated dependency rule enforces module boundaries.
- [ ] PR-blocking check exists for `internal` package leakage.
- [ ] Suppressions tracked with owner and expiry.

## Exceptions

List any intentional cross-module dependency or shared resource and the planned resolution:

-
