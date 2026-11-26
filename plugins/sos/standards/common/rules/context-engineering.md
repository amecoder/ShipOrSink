# Context Engineering Rules

AI agents must be given the smallest complete context needed to make a correct change. Context is an engineering artifact, not a chat convenience.

## Required Context

- Product intent: PRD, Feature Spec, user story, or issue.
- Repository facts: relevant files, current behavior, commands already run.
- Constraints: scope, out-of-scope work, security/privacy requirements, design system, performance budget.
- Verification: tests, typecheck, lint, browser checks, or manual command output required before handoff.

## Working Rules

- Prefer repository files such as `AGENTS.md`, `HANDOFF.md`, `AI_TASK_SPEC.md`, and ADRs over long chat-only instructions.
- Put durable instructions in versioned files; keep personal preferences in local settings.
- Remove stale context when the implementation direction changes.
- Do not paste secrets, production customer data, private prompts, or credentials into agent context.
- Keep examples concrete and close to the target stack.
- Context rot: recall degrades as the window fills, so a bigger window is not a reason to load more. Keep only what the next step needs.
- Just-in-time retrieval: keep paths, queries, and links in context and load the content when it is needed, instead of pasting everything up front.
- Compaction: at a task boundary, write decisions and open issues to `HANDOFF.md` (or the progress file), then compact or clear; do not carry raw tool output forward.
- Sub-agents return condensed summaries (conclusion + evidence paths), not their raw transcripts.

## Context Quality Gate

- Another agent can identify the goal, constraints, changed files, and next action within two minutes.
- Acceptance criteria are observable.
- The context names unknowns instead of hiding them behind assumptions.
- Long-running tasks have a progress file under `.codex/progress.md` or `.codex/long-horizon/<task>/`.
