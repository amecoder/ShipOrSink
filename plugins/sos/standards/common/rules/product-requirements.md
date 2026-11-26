---
paths:
  - "docs/**"
  - "**/PRD*.md"
  - "**/prd*.md"
  - "**/specs/**"
  - "**/product/**"
  - "**/*_SPEC*.md"
  - "**/*-spec*.md"
---

# Product Requirements Rules

AI agents must not implement ambiguous product ideas as code. Convert product intent into PRD and feature spec before implementation when behavior, UX, data, or user value is not already explicit.

## PRD Required When

- New user-facing workflow, MVP slice, pricing, onboarding, collaboration, permission, AI behavior, or data lifecycle is introduced.
- Requirements affect UX, API, data model, operations, security, privacy, or cost.
- Multiple implementation options exist and product tradeoffs matter.
- Acceptance criteria cannot be expressed as a small code-only change.

## PRD Contents

- Problem, target users, success metrics, non-goals, scope, user stories, acceptance criteria, risks, and rollout.
- Inputs, outputs, states, empty/error/loading behavior, and permission model.
- Data retention, privacy, AI provider usage, and cost constraints when relevant.
- MVP must separate must-have from later work.

## Feature Spec Contents

- Implementation-facing behavior derived from the PRD.
- UI states, API contracts, domain model, validation, errors, permissions, telemetry, tests, and migration plan.
- TDD test list before implementation.
- Refactoring and cleanup expectations after tests pass.

## Review Checklist

- PRD explains why the feature should exist.
- Spec explains exactly what to build.
- Acceptance criteria are testable.
- Non-goals prevent scope creep.
- Privacy, security, cost, and observability are addressed where relevant.
