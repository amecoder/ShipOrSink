# AI Review Checklist

Use this checklist when one AI agent reviews another agent's implementation.

## Critical

- [ ] The implementation matches the task spec and does not silently expand scope.
- [ ] Public API, route, schema, auth, billing, privacy, or data retention changes are safe.
- [ ] No secrets, credentials, customer data, or private environment files were added.
- [ ] Required tests and checks pass, or failures have a clear owner and next action.
- [ ] No unrelated user or agent changes were reverted.

## Warning

- [ ] Edge cases and failure modes are handled with user-friendly errors.
- [ ] LLM prompts, parsers, and fallbacks are deterministic enough to test.
- [ ] UI changes work on required desktop and mobile states.
- [ ] Documentation, changelog, handoff, and TODO files are updated where relevant.
- [ ] The change is small enough to review and roll back.

## Suggestion

- [ ] Names, boundaries, and abstractions match the existing project style.
- [ ] Tests assert behavior instead of implementation details.
- [ ] Follow-up work is explicit and not hidden in code comments.

## Review Output

```markdown
### Critical
- None

### Warning
- None

### Suggestion
- None

### Summary
- Verification reviewed:
- Residual risk:
```
