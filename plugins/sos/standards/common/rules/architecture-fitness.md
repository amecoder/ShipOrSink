---
paths:
  - "**/archunit/**"
  - "**/*ArchTest*"
  - "**/*arch*.test.*"
  - "**/*_arch_test.*"
  - "**/fitness/**"
  - ".dependency-cruiser.*"
  - "**/importlinter*"
  - "**/.importlinter"
  - "**/eslint.config.*"
  - "**/ArchUnit*"
---

# Architecture Fitness Functions Rules

Architecture decisions decay unless executable checks defend them. Encode the rules the team agreed on as automated tests that run in CI.

## What Must Be Encoded

- Layer dependency direction (domain has no framework imports, presentation does not import infrastructure directly).
- Module boundaries (feature module A does not depend on feature module B except through a published contract).
- Public API surface (exported symbols, stable packages, deprecated entry points).
- Performance budgets (latency, throughput, bundle size, memory) sampled on a defined workload.
- Reliability budgets (error rate, retry budget, queue lag) measured on canary or smoke runs.
- Security invariants (no plaintext secrets, no `eval`, no untrusted HTML render, dependency policy).
- Cost ceilings for AI / external API calls per request or per build.

## Implementation Choices

- JVM / Kotlin / Java: ArchUnit, Konsist, Modulith.
- .NET: NetArchTest, ArchUnitNET.
- TypeScript: dependency-cruiser, eslint-plugin-boundaries, sheriff.
- Python: import-linter, pytest-archon.
- Go: go-arch-lint, depguard via golangci-lint.
- Rust: cargo-deps, cargo-modules, custom xtask checks.
- Cross-language: SonarQube architecture rules, Semgrep custom rules, NX/TurboRepo project graph constraints.

## Required Practice

- Each architecture decision recorded in an ADR or design doc must point to its enforcing fitness function or explicitly mark itself as advisory.
- Fitness functions run on PR (fast layer/dependency checks) and on nightly / release candidate jobs (performance, cost, reliability checks).
- Failing a fitness function blocks the merge; suppressions require an ADR or a dated `// allow:` annotation with owner.
- Add a fitness function whenever the same architecture violation is fixed twice in code review.
- Track number and trend of suppressions; falling suppressions = healthy, growing suppressions = signal for refactor.

## Review Checklist

- Every layered/hexagonal/modular boundary has at least one automated check.
- CI surfaces fitness function results clearly, separate from unit tests.
- Performance, cost, and security budgets are evaluated against thresholds, not raw numbers.
- Suppressions list is reviewed at least quarterly.
- When the team changes a rule, the fitness function is updated in the same PR.
