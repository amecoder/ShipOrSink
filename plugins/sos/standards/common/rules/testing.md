---
paths:
  - "**/test_*"
  - "**/*_test.*"
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
---

# Testing Rules

## Coverage

- Minimum 80% line coverage for new code
- AI-generated code: 90% coverage required
- Coverage report in CI, fail under threshold

## TDD Workflow

1. RED: Write failing test first
2. GREEN: Implement minimum code to pass
3. REFACTOR: Clean up while tests pass

## Test Structure

- Arrange-Act-Assert (AAA) pattern
- One assertion concept per test (multiple asserts OK if same concept)
- Descriptive test names: `test_should_return_404_when_user_not_found`
- Table-driven tests for multiple input/output scenarios

## Property-Based Testing

- For pure logic with a rule that must hold for every input (money split, parsing round-trips, sorting, encoders,
  state machines), add a property test next to the examples: state the invariant, let the library generate inputs
  and shrink a failure to the smallest counterexample.
- Python: Hypothesis (`@given`) · TypeScript: fast-check (`fc.assert(fc.property(...))`). Runnable examples:
  `common/testing-templates/property-example.py` · `property-example.test.ts` (verified by `tests/enforcement-pbt.bats`).
- Good properties: round-trip (`decode(encode(x)) == x`), invariants (sum preserved, length kept), equivalence with a
  slow reference implementation, idempotence. Avoid restating the implementation inside the property.
- Keep one readable example test beside the properties — it documents intent for humans.
- CI must be reproducible: Hypothesis turns on its built-in `ci` profile when it detects a CI environment
  (`derandomize=True` — the same inputs every run, so search for new ones locally or in a nightly job with a higher
  `max_examples`); fast-check prints the seed of a failing run — replay it with `{ seed, path }` instead of re-running.

## Test Types

| Type | Scope | Speed | Coverage |
|------|-------|-------|----------|
| Unit | Function/class | Fast (<100ms) | 80%+ |
| Integration | API/DB | Medium (<5s) | Key flows |
| E2E | User journey | Slow (<30s) | Critical paths |

## Best Practices

- Tests must be independent (no shared mutable state)
- Use factories/fixtures for test data (no hardcoded values)
- Integration tests use real infrastructure you own — database, broker, cache — in containers (Testcontainers 2.x:
  Java/Kotlin `org.testcontainers:testcontainers-<module>` — version pinned in the language template, e.g.
  `kotlin-spring/templates/libs-quality.versions.toml`; Python `testcontainers[<module>]`; Node `testcontainers` +
  `@testcontainers/<module>`). Do not mock the database in integration tests: a mock cannot catch SQL, migration,
  transaction or constraint bugs. Unit tests may use a fake repository.
- Replace with a test double only what you do not own or cannot run (third-party HTTP APIs, payment, email), make
  non-deterministic inputs (clock, randomness) injectable, and use temp directories for the file system.
- Name test doubles precisely (Meszaros): **dummy** (passed, never used) · **stub** (returns canned answers) ·
  **spy** (stub that records calls) · **mock** (pre-programmed expectations, verifies calls) · **fake** (working
  lightweight implementation, e.g. in-memory repository). Prefer stubs and fakes; verify calls with mocks only when the
  call itself is the behavior (e.g. "an email is sent").
- Test edge cases: null, empty, boundary values, error paths
- No `sleep()` in tests — use polling/waitFor patterns

## Forbidden

- Tests that depend on execution order
- Tests that call real external APIs
- Empty test bodies or `assertTrue(true)`
- Ignoring/skipping tests without issue ticket reference
- Testing implementation details (test behavior, not internals)
