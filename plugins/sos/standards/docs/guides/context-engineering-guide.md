# Context Engineering Guide

## Goal

Context engineering makes AI work reproducible. The agent should receive enough product, code, and verification context to make a correct change, but not so much that stale information dominates.

## Context Packet

For meaningful work, prepare:

- Goal and non-goals.
- PRD, Feature Spec, ADR, or issue link.
- Relevant files and current behavior.
- Constraints: design, security, privacy, performance, cost.
- TDD and verification plan.
- Handoff location.

## Good Context

- Names files instead of saying "the backend".
- Defines acceptance criteria in observable terms.
- Explains why alternatives were rejected.
- States unknowns explicitly.
- Uses repository files for durable information.

## Bad Context

- Long chat history with no current task state.
- Product decisions hidden in conversation.
- Screenshots without expected behavior.
- Vague requests such as "make it better" without a quality bar.
- Secrets or customer data copied into agent prompts.

## Maintenance

- Update `HANDOFF.md` when scope or decisions change.
- Keep `AGENTS.md` concise and stable.
- Move task-specific details to `AI_TASK_SPEC.md` or `.codex/progress.md`.
- Delete or archive stale task context after completion.

## References

- OpenAI prompt engineering best practices: https://help.openai.com/en/articles/6654000-best-practices-for-prompt-engineering-with-openai-api
- Claude Code best practices: https://code.claude.com/docs/en/best-practices
