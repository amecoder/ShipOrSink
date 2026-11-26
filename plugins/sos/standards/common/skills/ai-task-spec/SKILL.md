---
name: ai-task-spec
description: "Turn a vague request into an implementable task spec: goal, in/out of scope, UX/API/data/security impact, files likely to change, verifiable acceptance criteria. Use at the start of any non-trivial task or when a request is ambiguous — 'spec this', '작업 명세', 'what exactly should I build', 'define scope'."
---

# AI Task Spec Rules

Every non-trivial AI coding task must start from an explicit task spec. The goal is to make the request implementable without hidden product decisions.

## Required Shape

- State the user goal in one or two concrete sentences.
- Define in-scope and out-of-scope work before editing code.
- List expected UX, API, data model, security, and operational impact when relevant.
- Name the files or subsystems likely to change when they are known.
- Define acceptance criteria that can be verified by tests, browser checks, or command output.

## Working Rules

- Do not implement vague requests by expanding scope silently.
- If a product decision changes the user experience, pricing, privacy, or stored data, record the decision in the project handoff or decision log.
- Prefer the smallest task slice that can ship with useful verification.
- Keep AI-generated plans tied to repository facts, not assumptions.

## Minimum Acceptance Criteria

- New behavior has at least one test or a documented verification reason.
- UI work names the required desktop and mobile states.
- Data changes name migration, rollback, and privacy implications.
- AI/LLM behavior names fallback, failure, and output validation expectations.
