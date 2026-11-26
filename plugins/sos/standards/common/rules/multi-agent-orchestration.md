# Multi-Agent Orchestration Rules

Claude Code, Codex, Gemini, and other agents may collaborate on one repository only when ownership, memory, and verification are explicit.

## Source of Truth

- `AGENTS.md`: shared rules for every agent.
- `CLAUDE.md`: Claude-specific adapter that imports or mirrors `AGENTS.md`.
- `GEMINI.md` or Gemini settings: Gemini-specific adapter that points to shared rules.
- `HANDOFF.md`: current state, decisions, blockers, verification, next actions.
- `CHANGELOG.md`: user-visible behavior, API, data, or operational changes.
- `.codex/progress.md`: active Codex session progress when the task is long-running.

## Role Defaults

- Gemini: research, alternative analysis, long document synthesis, external critique.
- Claude Code: repository exploration, planning, refactoring strategy, parallel subagent review.
- Codex: independent second-opinion review, bug analysis, and parallel implementation when delegated.
- Human owner: product decisions, risk acceptance, merge approval.

## Issue-Based Coordination

- The unit of work is a GitHub issue created from the `AI Task` form (goal, scope, out of scope, acceptance criteria, verification command). This applies to autonomous runs; an interactive request from a human in the session may start directly.
- Labels carry the state and live in git (`.github/labels.json`): `ai-task` → `ai-ready` → `ai-in-progress` → PR → merged. `needs-human` and `blocked` pause the flow.
- `ai-ready` is applied by a human after review. Agents never add it to their own or each other's issues.
- On pickup, the agent sets `ai-in-progress`, names the branch after the issue (`feat/123-short-title`), and comments the branch or PR link on the issue.
- Every PR body links its issue with `Closes #N`; the `pr-policy` check fails without it. Truly issue-less PRs (typos, CI tweaks) carry the `no-issue` label.
- Disagreements between agents are recorded as issue comments with the evidence (test output, docs), then decided by the human owner or by the tests.
- `HANDOFF.md` remains the session-level state (branch, commands run, blockers); the issue is the durable record of what was asked and accepted.

## Coordination Rules

- Claim ownership before editing shared files or broad modules.
- Do not revert another agent's changes unless the human owner explicitly requests it.
- Prefer small task slices with a named owner and verification command.
- Record changed files, commands, skipped checks, and blockers in `HANDOFF.md` or `.codex/progress.md`.
- When agents disagree, preserve both arguments and decide through tests, source docs, or a human decision.

## Handoff Gate

- The next agent can resume without rereading the entire chat.
- All critical checks are either passing or explicitly blocked with the exact reason.
- Product, architecture, and data decisions are recorded in the durable project files.
