---
name: ai-review-loop
description: "Second-pass review gate for AI-generated changes: when review is mandatory (routes, schemas, auth, billing, prompts, multi-subsystem), the implementer/reviewer protocol, severity ordering, and required checks. Use before handoff or PR of any non-trivial AI-written change — 'review this', '리뷰', 'second opinion', 'before I open the PR'."
---

# AI Review Loop Rules

AI-generated changes need a second pass focused on correctness, safety, and maintainability. Treat review as a blocking quality gate for meaningful changes.

## When Required

- Public routes, API contracts, database schemas, authentication, billing, privacy, or security-sensitive code changed.
- LLM prompts, output parsing, fallback logic, or provider routing changed.
- A UI flow that affects task completion changed.
- More than one subsystem changed in the same task.

## Review Process

- The implementer records intent, changed files, and verification before review.
- The reviewer checks repository facts, not just the final diff summary.
- Findings are ordered by severity and labeled `[필수]`, `[제안]`, `[Nit]`, or `[질문]` (same format as `AGENTS.md`).
- `[필수]` findings must be fixed or explicitly accepted by the user before handoff.
- The reviewer should avoid unrelated refactors and style churn.

## Required Checks

- Requirements and acceptance criteria match the delivered behavior.
- Tests cover the changed behavior and relevant regression paths.
- Security, privacy, and data retention rules are preserved.
- Error states are user-friendly and observable.
- Documentation and project memory are updated when needed.
