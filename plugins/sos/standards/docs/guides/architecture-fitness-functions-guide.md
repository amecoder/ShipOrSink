# Architecture Fitness Functions Guide

## Goal

Stop architecture from rotting. Encode the rules the team agreed on as automated checks that run in CI, so violations are caught at PR time instead of in a code review years later.

## What A Fitness Function Is

A fitness function is any automated test that evaluates whether the system still satisfies an architecture decision. It can be:

- Static: dependency direction, layering, public API surface, prohibited imports, ban-on-`eval`, secret patterns, license policy.
- Runtime: latency budget on a defined workload, error rate on canary, AI cost per request, cache hit rate.
- Build-time: bundle size, image size, compile time, transitive dependency count.

The point is the rule is executable. "Domain doesn't depend on Spring" is a wish; an ArchUnit test that fails the build is a fitness function.

## What To Encode First

Start with the rules that already cost the team time in code review:

1. Layer / module dependency direction.
2. Module boundaries in a modular monolith (no `internal` package leaks).
3. Public API surface stability (track exported symbols).
4. Forbidden patterns (e.g., direct ORM entity in controllers, unsafe eval, raw SQL in domain).
5. Latency / cost budgets for top business endpoints.
6. Bundle / image size budgets.

## Tools By Stack

| Stack | Tools |
|-------|-------|
| Kotlin / Java | ArchUnit, Konsist, Modulith, dependency-analysis-gradle-plugin |
| .NET | NetArchTest, ArchUnitNET |
| TypeScript / JS | dependency-cruiser, eslint-plugin-boundaries, sheriff, NX project-graph constraints |
| Python | import-linter, pytest-archon, Tach |
| Go | go-arch-lint, depguard (golangci-lint), impi |
| Rust | cargo-modules, cargo-deps, custom xtask |
| Cross-language | Sonar architecture rules, Semgrep custom rules, dbt structure tests |

For runtime budgets: k6, Lighthouse CI, size-limit, bundlesize, custom prom-query gates, OpenTelemetry-based gates in the release pipeline.

## Wiring Into CI

- Fast checks (deps, layering, lint-style) run on every PR. Target: < 5 minutes.
- Slow checks (perf, cost, reliability) run on nightly + release-candidate jobs.
- Failures must surface clearly and link to the rule + remediation hint.
- Treat fitness function failures the same as failing unit tests: red build, fix or justify.

## Suppression Discipline

Suppressions are unavoidable; uncontrolled suppressions are how this practice rots.

- Each suppression has: rule ID, owner, ADR or PR link, expiry date.
- Track total active suppressions over time. Trend up = signal for refactor.
- Review expired suppressions quarterly and either resolve or extend with new justification.

## Anti-Patterns

- One giant fitness function suite that takes 30 minutes and is ignored.
- Rules that mirror language compiler output (no benefit).
- Encoding aspirations that the codebase massively violates today; fix or sunset first, then enforce.
- Adding rules without owners; orphan rules become noise.

## Operating Cadence

- Add a fitness function the second time the same architecture issue is fixed in code review.
- Review the rule list with engineering leadership at least quarterly.
- When an ADR is approved, the implementing PR also adds (or updates) the corresponding fitness function.

## References

- Neal Ford, Rebecca Parsons, Patrick Kua, "Building Evolutionary Architectures".
- ArchUnit user guide, https://www.archunit.org/userguide/html/000_Index.html .
- dependency-cruiser, https://github.com/sverweij/dependency-cruiser .
- import-linter, https://import-linter.readthedocs.io .
