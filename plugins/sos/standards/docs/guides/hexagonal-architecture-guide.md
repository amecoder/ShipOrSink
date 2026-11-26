# Hexagonal / Clean Architecture Guide

## Goal

Build systems whose business logic survives changes in framework, persistence, transport, and AI provider. Hexagonal (ports-and-adapters) and clean architecture both push the same idea: dependencies point inward toward stable domain rules, and outer layers are replaceable.

## When To Apply

- A bounded context expected to outlive its current framework or DB.
- Code where business rules are entangled with HTTP / ORM / queue libraries today and that entanglement is hurting tests or onboarding.
- A new module in a modular monolith where future extraction into a service is plausible.
- AI features that may swap providers or move on-prem within 12 months.

When the system is a CRUD prototype or a script with a 6-month horizon, this pattern is overkill. Use the layered-architecture rule instead.

## Mental Model

- The hexagon is the domain + use cases.
- Around the hexagon are ports (interfaces) for everything the domain needs.
- Outside, adapters implement those ports for HTTP, DB, queue, mail, AI, time, identity.
- Wiring happens once, in a composition root.

```
[ HTTP / GraphQL / CLI ] -> (inbound adapter) -> [ use case ] -> [ domain ]
                                                       |
                                                       v
                                                 (port: Repo / Mailer / AI)
                                                       |
                                                       v
                                          [ outbound adapter -> Postgres / SES / OpenAI ]
```

## Mapping Ports

- Always a port: persistence, identity, payments, mail, push, queue publish, third-party APIs, time, randomness.
- Sometimes a port: feature flags, metrics (use OTel directly if your domain doesn't care about flags), logging.
- Never a port: pure libraries (math, parsing, regex) — depend directly.

## Practical Layout

```
src/
  user/
    domain/        entities, value objects, events, errors, ports
    application/   use cases, transactions, authorization
    adapters/
      inbound/     http controllers, queue consumers
      outbound/    postgres repo, mail adapter, llm adapter
    bootstrap/     wiring (DI container or manual factory)
    tests/
      domain/      pure unit tests
      application/ use case tests with fakes
      adapters/    contract / integration tests
```

## Tests By Layer

- Domain: pure unit, no IO. Tests run in milliseconds.
- Application: use case tests with in-memory port fakes.
- Adapters: integration tests against real DB / API or contract test doubles.
- End-to-end: assemble the hexagon in a single test or runtime to check wiring.

## Common Mistakes

- ORM entities used as domain entities. They drag mapping, lazy loading, and DB shape into the core.
- "Service" classes that do both orchestration and persistence calls. Split into a use case + a repo port.
- Hidden dependencies via globals, framework annotations, or service locators. Make them explicit ports injected at the composition root.
- Ports defined in adapter packages. Ports belong with the domain or application that owns the contract.

## Migration Path

- Identify the most painful part of the current code (often persistence inside controllers).
- Extract a port, add a fake, write use case tests.
- Move the existing implementation to an adapter behind the port.
- Repeat per capability. Do not big-bang the whole codebase.

## Fitness Functions

- Static check: domain package has no framework / ORM imports.
- Dependency cruiser / ArchUnit / import-linter rule: only allowed direction.
- Composition root must wire every port to one production adapter; missing bindings fail at startup, not at runtime.

## References

- Alistair Cockburn, "Hexagonal Architecture" (2005).
- Robert C. Martin, "Clean Architecture".
- Vaughn Vernon, "Implementing Domain-Driven Design".
