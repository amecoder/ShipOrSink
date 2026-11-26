# TDD Rules

Use test-driven development for new behavior and bug fixes unless the task is explicitly exploratory.

## Workflow

0. TEST LIST: before the first test, write the list of scenarios to cover (Canon TDD, Kent Beck 2023). Work one item
   at a time, add items as you discover them, and stop when the list is empty — not when one test passes.
1. RED: turn exactly one list item into a failing test that captures the required behavior.
2. GREEN: implement the smallest production change that passes it and all previous tests.
3. REFACTOR: improve names, structure, and duplication while keeping tests green.
4. VERIFY: run the narrow test first, then the relevant broader suite.

## Test Scope

- Unit tests cover pure logic, validators, reducers, formatters, and domain rules.
- Integration tests cover I/O boundaries, database queries, API handlers, queue consumers, and provider adapters.
- End-to-end tests cover only critical user workflows and regression-prone paths.
- Prefer deterministic fixtures and fake time over sleeps and real network calls.

## Coverage

- New or changed production code should meet at least 80% meaningful coverage.
- Security-sensitive, billing, auth, migration, and AI-output parsing paths need stronger branch coverage.
- Do not chase coverage by testing implementation details.
- Do not lower thresholds to make CI pass without a documented reason.

## Receipt

- Running the suite is what records progress: when a test command finishes successfully, the `test-receipt` hook stores the working-tree hash in `.git/claude/receipts.json` (shared by worktrees, never part of the tree).
- `git push` and `gh pr create` are blocked unless the tree of the commit being pushed has a receipt. Edit after testing → run the tests again, commit everything, then push. Partial staging is blocked on purpose.
- Only a real run counts: the runner must be the last command in the chain (`pytest || true`, `pytest | tail` do not count), and `--version`, `--collect-only`, `--dry-run`, `-DskipTests`, `-k`, `-m`, `::` selectors are rejected. Set `env.TEST_CMD` in `.claude/settings.json` to accept exactly one canonical command.
- The receipt proves "the suite passed on this tree" to the hook, not to the world: with unrestricted Bash an agent could forge it. CI required checks are the real gate; the receipt makes lazy shortcuts expensive.

## Regression Fixes

- Every bug fix starts with a test that fails on the old behavior.
- Keep the regression test close to the layer where the bug was observable.
- Add a short comment only when the edge case is not obvious from the test name.
