# Project Memory Rules

Long-running AI work needs durable project memory. Use repository-local memory files so another agent can continue without guessing.

## Standard Files

- `HANDOFF.md`: product state, architecture state, current decisions, next actions.
- `TODO.md` or `TODOS.md`: deferred work that is intentionally out of scope.
- `CHANGELOG.md`: user-visible behavior, API, data model, or operational changes.
- `docs/DECISIONS.md` or `docs/adr/`: architecture and product decisions.
- `.codex/progress.md`: active Codex session log, changed files, commands, blockers.
- `CLAUDE.md` and `AGENTS.md`: agent-specific and shared working rules.

## Update Rules

- Read memory files before changing code.
- Update memory files when scope, architecture, data, dependencies, or next actions change.
- Do not store secrets, credentials, customer data, or private prompts in memory files.
- Prefer concise dated entries over long narratives.
- Preserve another agent's notes unless the user explicitly asks to remove them.

## Handoff Quality

- A new agent should know the branch, current state, changed files, verification, blockers, and next action within two minutes.
- If a check was skipped, record the exact reason.
- If a task is deferred, record why it is deferred and what would make it ready.
