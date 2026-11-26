# Definition of Done Rules

A task is not done when the code compiles. It is done when the behavior, safety checks, and handoff trail are complete.

## Required Before Handoff

- Run the narrowest relevant tests first, then the broader check that protects the changed area.
- Run formatting, linting, type checking, or build checks that the project already defines.
- Confirm secrets, environment files, generated artifacts, and unrelated user changes were not accidentally modified.
- Update user-facing docs, changelog, handoff, TODO, or decision records when the change affects them.
- Record commands run and any skipped checks with a concrete reason.

## Evidence Hierarchy

Done is judged by evidence the model cannot write itself. From weakest to strongest:

1. A checkbox or "done" claim written by the model — not evidence.
2. An artifact the model produced (diff, generated file) — shows work, not correctness.
3. A command result (test exit code, build log, CI status) — evidence.
4. A host event (hook receipt in `.git/claude/receipts.json`, CI check on the PR) — strongest available locally; CI checks are the only evidence the model cannot alter at all.

Use levels 3 and 4 for every required item. Keep checkboxes only for human judgment (product fit, naming, risk acceptance).

## Blocking Conditions

- Failing tests without an explicit owner and next action.
- New behavior without verification.
- Hidden breaking changes in public APIs, schemas, routes, permissions, or persisted data.
- Error messages that leak internals or leave users without a recovery path.
- Unreviewed force pushes, destructive commands, or secret-bearing files.

## Review-Ready Output

- Summarize what changed at behavior level.
- List verification commands and results.
- Call out remaining risks or follow-up work.
- Keep the final response short enough for the next engineer or agent to act on immediately.
