---
name: plan-mode-workflow
description: "When to plan before editing and what a good plan contains: goal/non-goals, repository facts, approach and rejected alternatives, file ownership, TDD plan, verification and rollback. Use when a task changes architecture, data, security, billing, user workflows, or multiple subsystems — 'plan this', '계획', 'how should we approach', 'design first'."
---

# Plan Mode Workflow Rules

Use plan mode before editing when the task changes architecture, data, security, billing, user workflows, or multiple subsystems.

## When Required

- New feature with unclear scope or more than one implementation path.
- Database, API contract, event contract, authentication, authorization, privacy, billing, or infrastructure change.
- Large refactor, migration, or dependency upgrade.
- Multi-agent work where file ownership must be split.

## Plan Shape

- Goal and non-goals.
- Current repository facts, with files inspected.
- Proposed approach and alternatives rejected.
- File ownership and expected write set.
- TDD plan: RED, GREEN, REFACTOR.
- Verification plan and rollback path.

## Execution Rules

- Do not turn planning into implementation.
- Switch to implementation only after the plan is coherent and scoped.
- Update the plan when facts invalidate it.
- Keep the plan short enough to be actionable; move durable details into `AI_TASK_SPEC.md`, ADR, or `HANDOFF.md`.

## Completion Gate

- Implementation matches the accepted plan or records why it changed.
- Deferred work is moved to `TODO.md`, `HANDOFF.md`, or a tracked issue.
