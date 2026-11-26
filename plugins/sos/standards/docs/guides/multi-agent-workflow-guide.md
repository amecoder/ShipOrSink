# Multi-Agent Workflow Guide

## Goal

Let Codex, Claude Code, Gemini, and humans work in the same repository without losing context or overwriting each other.

## Recommended Operating Model

| Role | Default responsibility |
|------|------------------------|
| Gemini | External research, alternative analysis, long document synthesis |
| Claude Code | Repository exploration, plan mode, refactoring strategy, review |
| Codex | Implementation, tests, browser validation, integration handoff |
| Human | Product decisions, risk acceptance, merge approval |

## Shared Files

- `AGENTS.md`: shared agent instructions.
- `CLAUDE.md`: Claude Code adapter.
- `GEMINI.md` or `.gemini/settings.json`: Gemini adapter.
- `HANDOFF.md`: current state and next action.
- `CHANGELOG.md`: user-visible changes.
- `.codex/progress.md`: active Codex session state.

## Workflow

1. Define PRD or Feature Spec for product-facing work.
2. Convert the next slice into `AI_TASK_SPEC.md`.
3. Assign owners and expected write sets.
4. Let research/review agents work on read-only or disjoint tasks.
5. Implement with TDD.
6. Run adversarial review.
7. Update handoff and changelog.

## Conflict Rules

- Do not revert another agent's edits by default.
- Stop if two agents need to own the same file at the same time.
- Resolve disagreement with tests, source docs, or a human decision.
- Preserve decision rationale in ADR or `HANDOFF.md`.

## References

- AGENTS.md: https://agents.md/
- Claude Code memory: https://code.claude.com/docs/en/memory
- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Gemini CLI context files: https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html
