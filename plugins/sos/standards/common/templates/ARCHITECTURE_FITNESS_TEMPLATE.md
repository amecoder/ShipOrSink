# Architecture Fitness Functions Template

Document and operationalize the architectural rules the team agreed on so they cannot silently rot.

## Scope

- System / module:
- Owner:
- Related ADRs / Design Docs:

## Encoded Rules

| ID | Rule | Layer / Module | Tool | Test File / Job | Severity (block / warn) | Owner |
|----|------|----------------|------|-----------------|------------------------|-------|
| F-01 | Domain has no framework imports | domain | ArchUnit / dependency-cruiser / import-linter | | block | |
| F-02 | Feature module A does not depend on B except through public API | modules | | | block | |
| F-03 | Public API surface stable list | api | API extractor / oasdiff · buf breaking (`ci-api-contract.yml`) | | warn → block on next major | |
| F-04 | p95 latency on `/checkout` ≤ 300ms on canary | runtime | k6 + threshold | | block on release | |
| F-05 | AI cost per request ≤ $0.05 average | runtime | metrics + alert | | warn / page on breach | |
| F-06 | No plaintext secrets / unsafe APIs | code | Semgrep / gitleaks | | block | |
| F-07 | Bundle size budget ≤ 250KB initial | build | size-limit / bundlesize | | block | |

## CI Wiring

- Fast checks (layer, dependency, lint-style) run on every PR within N minutes.
- Slow checks (perf, cost, reliability) run on nightly + release candidate jobs.
- Failures surface in PR with link to the rule and remediation hint.

## Suppression Policy

- A suppression must include: rule ID, owner, ADR or PR link, expiry date.
- Suppression list is reviewed at least quarterly; expired suppressions become open issues.

## Metrics

- Number of active suppressions:
- Number added / removed in last quarter:
- Mean time to resolve a fitness function failure on `main`:

## Open Items

-
