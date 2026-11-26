---
paths:
  - "**/domain/**"
  - "**/application/**"
  - "**/infrastructure/**"
  - "**/adapters/**"
  - "**/ports/**"
  - "**/internal/**"
  - "**/pkg/**"
  - "docs/adr/**"
  - "docs/design-docs/**"
  - "docs/architecture/**"
---

# Architecture Rules

Architecture work must make system boundaries, data ownership, and operational behavior explicit.

## Design Discipline

- Use a short design note or ADR for cross-cutting changes, data model changes, public APIs, auth, billing, async workflows, or irreversible migrations.
- Prefer boring, well-supported technology until a specific constraint requires more.
- Optimize for reversibility: isolate experiments behind interfaces, feature flags, or adapters.
- Keep the MVP architecture modular without prematurely splitting services.

## Boundaries

- Define ownership for each domain module, data table, queue topic, and external integration.
- Dependencies should point inward toward stable domain contracts, not outward toward UI or transport details.
- Shared modules may not depend on feature modules.
- Avoid circular dependencies; if one appears, extract a smaller contract or event.

## Data And APIs

- Treat schemas, API contracts, and event payloads as versioned interfaces.
- Validate input at boundaries and normalize once.
- Use explicit migration plans for database changes, including rollback or forward-fix strategy.
- Do not expose internal identifiers, stack traces, provider errors, or raw SQL errors to clients.

## Operations

- Define logs, metrics, traces, and alerts for user-facing workflows before production release.
- Every external dependency needs timeout, retry, and fallback behavior appropriate to the use case.
- Long-running work should be resumable or idempotent.
- Architecture is not complete until failure modes and operational ownership are documented.
