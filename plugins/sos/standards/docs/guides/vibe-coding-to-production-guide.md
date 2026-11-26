# Vibe Coding to Production Guide

## Goal

Use natural-language prototyping for speed without letting prototype practices become production standards.

## Two Modes

| Mode | Output | Gate |
|------|--------|------|
| Exploration | Spike, mock, prompt draft, UX option | Can be discarded |
| Production | Tested, reviewed, documented implementation | Must pass DoD |

## Exploration Rules

- Timebox the spike.
- Keep dependencies and data changes temporary.
- Avoid secrets and customer data.
- Capture useful learnings in `HANDOFF.md` or a short decision note.

## Production Promotion

Before shipping:

- Write PRD, Feature Spec, or AI Task Spec.
- Add failing tests first.
- Remove debug paths and unused code.
- Review security, privacy, cost, and operations.
- Run evals for AI behavior.
- Update changelog and handoff.

## Best-of-N Pattern

Multiple agents may propose solutions. Select with explicit criteria:

- Correctness against acceptance criteria.
- Smallest maintainable change.
- Testability.
- Security and privacy risk.
- Operational cost.

## References

- Vibe coding empirical study: https://arxiv.org/abs/2506.23253
- Vibe coding and agentic coding analysis: https://arxiv.org/abs/2505.19443
