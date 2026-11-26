---
name: refactoring
description: "Behavior-preserving refactoring workflow: characterizing tests first, small reviewable scope, AI guardrails against invented abstractions or wholesale rewrites. Use when restructuring code without changing behavior — 'refactor', '리팩터링', 'clean up', 'extract', 'split this module' — or when a task mixes refactoring with a behavior change."
---

# Refactoring Rules

Refactoring changes structure without changing externally observable behavior. When behavior changes, treat it as a feature or bug fix and update tests/specs first.

## Before Refactoring

- Identify the smell or risk: duplication, long function, large file, deep nesting, coupling, unclear names, unsafe boundary, slow test, or brittle abstraction.
- Capture current behavior with tests before changing structure.
- Keep the refactor scope small enough to review.
- Do not mix broad formatting churn with semantic refactoring.

## Safe Refactoring

- Prefer extract function, extract module, introduce parameter object, replace conditional with polymorphism/strategy, and move boundary mapping to edges.
- Keep public APIs stable unless a migration plan exists.
- Preserve error behavior, telemetry names, metrics labels, and data compatibility.
- Use automated formatters after structural changes.
- Delete dead code only when references are verified.

## AI Refactoring Guardrails

- Do not invent abstractions to make code look cleaner without reducing coupling, duplication, or risk.
- Do not rewrite working modules wholesale when targeted changes would solve the problem.
- Do not change architecture boundaries without a spec or ADR.
- Keep renamed symbols consistent across tests, docs, and contracts.

## After Refactoring

- Run tests covering the touched behavior.
- Run lint/typecheck/build when relevant.
- Document risk, verification, and follow-up in handoff notes.
- Update architecture docs when boundaries changed.

## Review Checklist

- Behavior-preserving tests existed before the refactor.
- The refactor has a clear reason.
- Diff is reviewable and scoped.
- Public contracts remain compatible or migration is documented.
- Verification commands are recorded.
