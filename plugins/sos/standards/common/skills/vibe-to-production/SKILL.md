---
name: vibe-to-production
description: "Promotion gate from natural-language prototype to production code: spec, tests that fail on old behavior, architecture/security/cost review, dead-branch cleanup, CHANGELOG/HANDOFF. Use when a spike, prototype, or 'looks right' code is about to be merged or shipped — 'productionize', '프로덕션으로', 'make this real', 'ship it'."
---

# Vibe-to-Production Rules

Natural-language prototyping is allowed for exploration. Production code still requires specification, tests, review, and observable acceptance criteria.

## Allowed

- Fast UX prototypes, throwaway spikes, prompt experiments, and option exploration.
- Using AI to generate candidate implementations.
- Best-of-N comparison when multiple agents propose alternatives.

## Not Allowed

- Shipping code whose expected behavior is only described in chat.
- Skipping tests because the prototype "looks right".
- Letting generated code introduce dependencies, schemas, or external services without a decision record.
- Mixing exploratory prompt text with production secrets or customer data.

## Promotion Gate

Before prototype code becomes production code:

- Convert the idea into PRD, Feature Spec, or AI Task Spec.
- Add tests that fail on the old behavior and pass on the new behavior.
- Review architecture, security, privacy, cost, and operational impact.
- Remove dead branches, debug UI, unused dependencies, and vague TODOs.
- Record user-visible changes in `CHANGELOG.md` and next work in `HANDOFF.md`.

## Review Questions

- What behavior is guaranteed now?
- What failure modes are intentionally handled?
- What is still exploratory and out of scope?
- Which checks prove that the implementation is ready?
