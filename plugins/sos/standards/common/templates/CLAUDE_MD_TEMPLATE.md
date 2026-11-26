# CLAUDE.md

This file adapts the shared project rules for Claude Code.

## Shared Rules

@AGENTS.md

General project rules live in `AGENTS.md` (imported above) so Codex, Claude Code, Gemini, and humans share the same source of truth.

## Claude Code Workflow

- Start in plan mode for architecture, data, security, billing, multi-file refactors, or unclear scope.
- Read `HANDOFF.md`, `CHANGELOG.md`, and relevant docs before editing.
- Use repository facts over assumptions.
- Keep changes scoped to the current task.
- Update `HANDOFF.md` when scope, decisions, verification, blockers, or next actions change.
- Do not revert changes made by another agent unless the human owner explicitly asks.

## Required Handoff

Record:

- Goal and current state.
- Files changed.
- Commands run and results.
- Checks skipped with exact reason.
- Risks, blockers, and next actions.

## Review Format

Follow the review format in `AGENTS.md` (`[필수]` / `[제안]` / `[Nit]` / `[질문]`).
