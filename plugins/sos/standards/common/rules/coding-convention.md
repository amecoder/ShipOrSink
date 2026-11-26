# Coding Convention Rules

Code should be readable, easy to review, and hard to misuse.

## Structure

- Prefer small functions with one reason to change; keep functions under 50 lines when practical.
- Prefer files under 800 lines; split earlier when a smaller file improves clarity.
- Avoid nesting deeper than four levels.
- Extract constants for repeated or domain-significant values.
- Do not add abstractions until they remove real duplication or clarify a boundary.

## Data Handling

- Prefer immutable updates over mutation.
- Validate at I/O boundaries and keep internal types trustworthy.
- Use structured parsers and serializers instead of ad hoc string manipulation for JSON, YAML, SQL, HTML, XML, and URLs.
- Treat dates, money, time zones, and locale-sensitive text as explicit domain values.

## Errors

- Handle errors at user-facing and I/O boundaries with clear messages.
- Let shared error handlers manage internal propagation where the framework supports it.
- Include enough diagnostic context in logs without exposing secrets or personal data.
- Never swallow errors silently.

## Naming And Comments

- Use descriptive names that match the domain vocabulary.
- Keep casing consistent with the language and framework.
- Comments explain why, constraints, or non-obvious behavior; they do not narrate obvious code.
- Remove dead code instead of commenting it out.

## Production Hygiene

- No `console.log`, `print`, or debug statements in production code.
- No hardcoded secrets, account IDs, tokens, or provider credentials.
- Prefer configuration and environment variables for deploy-time values.
- Keep public APIs backward compatible unless the breaking change is planned and documented.
